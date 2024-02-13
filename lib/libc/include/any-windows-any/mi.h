/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#ifndef _MI_h
#define _MI_h

#include <stddef.h>
#include <stdio.h>
#include <string.h>

#pragma pack(push, 8)

#if defined(MI_CHAR_TYPE)
#if (MI_CHAR_TYPE != 1) && (MI_CHAR_TYPE != 2)
#error "MI_CHAR_TYPE must be 1 or 2"
#endif
#else
#define MI_CHAR_TYPE 2
#endif

#if (MI_CHAR_TYPE == 2)
#define MI_USE_WCHAR
#endif

#ifndef MI_CONST
#define MI_CONST const
#endif

#define MI_MAJOR ((MI_Uint32)1)
#define MI_MINOR ((MI_Uint32)0)
#define MI_REVISON ((MI_Uint32)0)
#define MI_MAKE_VERSION(MAJ, MIN, REV) ((MAJ << 16) | (MIN << 8) | REV)
#define MI_VERSION MI_MAKE_VERSION(MI_MAJOR, MI_MINOR, MI_REVISON)

#define MI_UNREFERENCED_PARAMETER(P) (P)

#define MI_EXPORT __declspec(dllexport)

#define MI_MAIN_CALL __cdecl

#define MI_CALL __stdcall

#ifdef _MANAGED_PURE
#define MI_INLINE_CALL
#else
#define MI_INLINE_CALL MI_CALL
#endif

#define MI_INLINE static __inline

#define MI_OFFSETOF(STRUCT,FIELD) (((ptrdiff_t)&(((STRUCT*)1)->FIELD))-1)

#ifdef __cplusplus
#define MI_EXTERN_C extern "C"
#else
#define MI_EXTERN_C extern
#endif

#define MI_COUNT(X) (sizeof(X)/sizeof(X[0]))

#if (MI_CHAR_TYPE == 1)
#define MI_T(STR) STR
#else
#define MI_T(STR) L##STR
#endif

#define MI_LL(X) X##i64
#define MI_ULL(X) X##ui64

typedef struct _MI_Server MI_Server;
typedef struct _MI_Context MI_Context;
typedef struct _MI_ClassDecl MI_ClassDecl;
typedef struct _MI_Instance MI_Instance;
typedef struct _MI_Filter MI_Filter;
typedef struct _MI_PropertySet MI_PropertySet;
typedef struct _MI_Qualifier MI_Qualifier;
typedef struct _MI_Session MI_Session;
typedef struct _MI_ServerFT MI_ServerFT;
typedef struct _MI_ProviderFT MI_ProviderFT;
typedef struct _MI_PropertySetFT MI_PropertySetFT;
typedef struct _MI_InstanceFT MI_InstanceFT;
typedef struct _MI_ContextFT MI_ContextFT;
typedef struct _MI_FilterFT MI_FilterFT;
typedef struct _MI_Class MI_Class;
typedef struct _MI_InstanceExFT MI_InstanceExFT;

typedef enum _MI_Result {
  MI_RESULT_OK = 0,
  MI_RESULT_FAILED = 1,
  MI_RESULT_ACCESS_DENIED = 2,
  MI_RESULT_INVALID_NAMESPACE = 3,
  MI_RESULT_INVALID_PARAMETER = 4,
  MI_RESULT_INVALID_CLASS = 5,
  MI_RESULT_NOT_FOUND = 6,
  MI_RESULT_NOT_SUPPORTED = 7,
  MI_RESULT_CLASS_HAS_CHILDREN = 8,
  MI_RESULT_CLASS_HAS_INSTANCES = 9,
  MI_RESULT_INVALID_SUPERCLASS = 10,
  MI_RESULT_ALREADY_EXISTS = 11,
  MI_RESULT_NO_SUCH_PROPERTY = 12,
  MI_RESULT_TYPE_MISMATCH = 13,
  MI_RESULT_QUERY_LANGUAGE_NOT_SUPPORTED = 14,
  MI_RESULT_INVALID_QUERY = 15,
  MI_RESULT_METHOD_NOT_AVAILABLE = 16,
  MI_RESULT_METHOD_NOT_FOUND = 17,
  MI_RESULT_NAMESPACE_NOT_EMPTY = 20,
  MI_RESULT_INVALID_ENUMERATION_CONTEXT = 21,
  MI_RESULT_INVALID_OPERATION_TIMEOUT = 22,
  MI_RESULT_PULL_HAS_BEEN_ABANDONED = 23,
  MI_RESULT_PULL_CANNOT_BE_ABANDONED = 24,
  MI_RESULT_FILTERED_ENUMERATION_NOT_SUPPORTED = 25,
  MI_RESULT_CONTINUATION_ON_ERROR_NOT_SUPPORTED = 26,
  MI_RESULT_SERVER_LIMITS_EXCEEDED = 27,
  MI_RESULT_SERVER_IS_SHUTTING_DOWN = 28
} MI_Result;

typedef enum _MI_ErrorCategory {
  MI_ERRORCATEGORY_NOT_SPECIFIED = 0,
  MI_ERRORCATEGORY_OPEN_ERROR = 1,
  MI_ERRORCATEGORY_CLOS_EERROR = 2,
  MI_ERRORCATEGORY_DEVICE_ERROR = 3,
  MI_ERRORCATEGORY_DEADLOCK_DETECTED = 4,
  MI_ERRORCATEGORY_INVALID_ARGUMENT = 5,
  MI_ERRORCATEGORY_INVALID_DATA = 6,
  MI_ERRORCATEGORY_INVALID_OPERATION = 7,
  MI_ERRORCATEGORY_INVALID_RESULT = 8,
  MI_ERRORCATEGORY_INVALID_TYPE = 9,
  MI_ERRORCATEGORY_METADATA_ERROR = 10,
  MI_ERRORCATEGORY_NOT_IMPLEMENTED = 11,
  MI_ERRORCATEGORY_NOT_INSTALLED = 12,
  MI_ERRORCATEGORY_OBJECT_NOT_FOUND = 13,
  MI_ERRORCATEGORY_OPERATION_STOPPED = 14,
  MI_ERRORCATEGORY_OPERATION_TIMEOUT = 15,
  MI_ERRORCATEGORY_SYNTAX_ERROR = 16,
  MI_ERRORCATEGORY_PARSER_ERROR = 17,
  MI_ERRORCATEGORY_ACCESS_DENIED = 18,
  MI_ERRORCATEGORY_RESOURCE_BUSY = 19,
  MI_ERRORCATEGORY_RESOURCE_EXISTS = 20,
  MI_ERRORCATEGORY_RESOURCE_UNAVAILABLE = 21,
  MI_ERRORCATEGORY_READ_ERROR = 22,
  MI_ERRORCATEGORY_WRITE_ERROR = 23,
  MI_ERRORCATEGORY_FROM_STDERR = 24,
  MI_ERRORCATEGORY_SECURITY_ERROR = 25,
  MI_ERRORCATEGORY_PROTOCOL_ERROR = 26,
  MI_ERRORCATEGORY_CONNECTION_ERROR = 27,
  MI_ERRORCATEGORY_AUTHENTICATION_ERROR = 28,
  MI_ERRORCATEGORY_LIMITS_EXCEEDED = 29,
  MI_ERRORCATEGORY_QUOTA_EXCEEDED = 30,
  MI_ERRORCATEGORY_NOT_ENABLED = 31
} MI_ErrorCategory;

typedef enum _MI_PromptType {
  MI_PROMPTTYPE_NORMAL,
  MI_PROMPTTYPE_CRITICAL
} MI_PromptType;

typedef enum _MI_CallbackMode {
  MI_CALLBACKMODE_REPORT,
  MI_CALLBACKMODE_INQUIRE,
  MI_CALLBACKMODE_IGNORE
} MI_CallbackMode;

typedef enum _MI_ProviderArchitecture {
  MI_PROVIDER_ARCHITECTURE_32BIT,
  MI_PROVIDER_ARCHITECTURE_64BIT
} MI_ProviderArchitecture;

#define MI_FLAG_CLASS (1 << 0)
#define MI_FLAG_METHOD (1 << 1)
#define MI_FLAG_PROPERTY (1 << 2)
#define MI_FLAG_PARAMETER (1 << 3)
#define MI_FLAG_ASSOCIATION (1 << 4)
#define MI_FLAG_INDICATION (1 << 5)
#define MI_FLAG_REFERENCE (1 << 6)
#define MI_FLAG_ANY (1|2|4|8|16|32|64)

#define MI_FLAG_ENABLEOVERRIDE (1 << 7)
#define MI_FLAG_DISABLEOVERRIDE (1 << 8)
#define MI_FLAG_RESTRICTED (1 << 9)
#define MI_FLAG_TOSUBCLASS (1 << 10)
#define MI_FLAG_TRANSLATABLE (1 << 11)

#define MI_FLAG_KEY (1 << 12)
#define MI_FLAG_IN (1 << 13)
#define MI_FLAG_OUT (1 << 14)
#define MI_FLAG_REQUIRED (1 << 15)
#define MI_FLAG_STATIC (1 << 16)
#define MI_FLAG_ABSTRACT (1 << 17)
#define MI_FLAG_TERMINAL (1 << 18)
#define MI_FLAG_EXPENSIVE (1 << 19)
#define MI_FLAG_STREAM (1 << 20)
#define MI_FLAG_READONLY (1 << 21)

#define MI_FLAG_EXTENDED (1 << 12)
#define MI_FLAG_NOT_MODIFIED (1 << 25)
#define MI_FLAG_VERSION (1<<26|1<<27|1<<28)
#define MI_FLAG_NULL (1 << 29)
#define MI_FLAG_BORROW (1 << 30)
#define MI_FLAG_ADOPT ((MI_Uint32)(1 << 31))

typedef enum _MI_Type {
  MI_BOOLEAN = 0,
  MI_UINT8 = 1,
  MI_SINT8 = 2,
  MI_UINT16 = 3,
  MI_SINT16 = 4,
  MI_UINT32 = 5,
  MI_SINT32 = 6,
  MI_UINT64 = 7,
  MI_SINT64 = 8,
  MI_REAL32 = 9,
  MI_REAL64 = 10,
  MI_CHAR16 = 11,
  MI_DATETIME = 12,
  MI_STRING = 13,
  MI_REFERENCE = 14,
  MI_INSTANCE = 15,
  MI_BOOLEANA = 16,
  MI_UINT8A = 17,
  MI_SINT8A = 18,
  MI_UINT16A = 19,
  MI_SINT16A = 20,
  MI_UINT32A = 21,
  MI_SINT32A = 22,
  MI_UINT64A = 23,
  MI_SINT64A = 24,
  MI_REAL32A = 25,
  MI_REAL64A = 26,
  MI_CHAR16A = 27,
  MI_DATETIMEA = 28,
  MI_STRINGA = 29,
  MI_REFERENCEA = 30,
  MI_INSTANCEA = 31,
  MI_ARRAY = 16
} MI_Type;

typedef unsigned char MI_Boolean;
typedef unsigned char MI_Uint8;
typedef signed char MI_Sint8;
typedef unsigned short MI_Uint16;
typedef signed short MI_Sint16;
typedef unsigned int MI_Uint32;
typedef signed int MI_Sint32;

typedef unsigned __int64 MI_Uint64;
typedef signed __int64 MI_Sint64;

typedef float MI_Real32;
typedef double MI_Real64;
typedef unsigned short MI_Char16;

#if (MI_CHAR_TYPE == 1)
typedef char MI_Char;
#else
typedef wchar_t MI_Char;
#endif

typedef MI_Char* MI_StringPtr;
typedef const MI_Char* MI_ConstStringPtr;

#define MI_TRUE ((MI_Boolean)1)
#define MI_FALSE ((MI_Boolean)0)

typedef struct _MI_Timestamp {
  MI_Uint32 year;
  MI_Uint32 month;
  MI_Uint32 day;
  MI_Uint32 hour;
  MI_Uint32 minute;
  MI_Uint32 second;
  MI_Uint32 microseconds;
  MI_Sint32 utc;
} MI_Timestamp;

typedef struct _MI_Interval {
  MI_Uint32 days;
  MI_Uint32 hours;
  MI_Uint32 minutes;
  MI_Uint32 seconds;
  MI_Uint32 microseconds;
  MI_Uint32 __padding1;
  MI_Uint32 __padding2;
  MI_Uint32 __padding3;
} MI_Interval;

typedef struct _MI_Datetime {
  MI_Uint32 isTimestamp;
  union {
    MI_Timestamp timestamp;
    MI_Interval interval;
  } u;
} MI_Datetime;

typedef struct _MI_BooleanA {
  MI_Boolean* data;
  MI_Uint32 size;
} MI_BooleanA;

typedef struct _MI_Uint8A {
  MI_Uint8* data;
  MI_Uint32 size;
} MI_Uint8A;

typedef struct _MI_Sint8A {
  MI_Sint8* data;
  MI_Uint32 size;
} MI_Sint8A;

typedef struct _MI_Uint16A {
  MI_Uint16* data;
  MI_Uint32 size;
} MI_Uint16A;

typedef struct _MI_Sint16A {
  MI_Sint16* data;
  MI_Uint32 size;
} MI_Sint16A;

typedef struct _MI_Uint32A {
  MI_Uint32* data;
  MI_Uint32 size;
} MI_Uint32A;

typedef struct _MI_Sint32A {
  MI_Sint32* data;
  MI_Uint32 size;
} MI_Sint32A;

typedef struct _MI_Uint64A {
  MI_Uint64* data;
  MI_Uint32 size;
} MI_Uint64A;

typedef struct _MI_Sint64A {
  MI_Sint64* data;
  MI_Uint32 size;
} MI_Sint64A;

typedef struct _MI_Real32A {
  MI_Real32* data;
  MI_Uint32 size;
} MI_Real32A;

typedef struct _MI_Real64A {
  MI_Real64* data;
  MI_Uint32 size;
} MI_Real64A;

typedef struct _MI_Char16A {
  MI_Char16* data;
  MI_Uint32 size;
} MI_Char16A;

typedef struct _MI_DatetimeA {
  MI_Datetime* data;
  MI_Uint32 size;
} MI_DatetimeA;

typedef struct _MI_StringA {
  MI_Char** data;
  MI_Uint32 size;
} MI_StringA;

typedef struct _MI_ReferenceA {
  struct _MI_Instance** data;
  MI_Uint32 size;
} MI_ReferenceA;

typedef struct _MI_InstanceA {
  MI_Instance** data;
  MI_Uint32 size;
} MI_InstanceA;

typedef struct _MI_Array {
  void* data;
  MI_Uint32 size;
} MI_Array;

typedef struct _MI_ConstBooleanA {
  MI_CONST MI_Boolean* data;
  MI_Uint32 size;
} MI_ConstBooleanA;

typedef struct _MI_ConstUint8A {
  MI_CONST MI_Uint8* data;
  MI_Uint32 size;
} MI_ConstUint8A;

typedef struct _MI_ConstSint8A {
  MI_CONST MI_Sint8* data;
  MI_Uint32 size;
} MI_ConstSint8A;

typedef struct _MI_ConstUint16A {
  MI_CONST MI_Uint16* data;
  MI_Uint32 size;
} MI_ConstUint16A;

typedef struct _MI_ConstSint16A {
  MI_CONST MI_Sint16* data;
  MI_Uint32 size;
} MI_ConstSint16A;

typedef struct _MI_ConstUint32A {
  MI_CONST MI_Uint32* data;
  MI_Uint32 size;
} MI_ConstUint32A;

typedef struct _MI_ConstSint32A {
  MI_CONST MI_Sint32* data;
  MI_Uint32 size;
} MI_ConstSint32A;

typedef struct _MI_ConstUint64A {
  MI_CONST MI_Uint64* data;
  MI_Uint32 size;
} MI_ConstUint64A;

typedef struct _MI_ConstSint64A {
  MI_CONST MI_Sint64* data;
  MI_Uint32 size;
} MI_ConstSint64A;

typedef struct _MI_ConstReal32A {
  MI_CONST MI_Real32* data;
  MI_Uint32 size;
} MI_ConstReal32A;

typedef struct _MI_ConstReal64A {
  MI_CONST MI_Real64* data;
  MI_Uint32 size;
} MI_ConstReal64A;

typedef struct _MI_ConstChar16A {
  MI_CONST MI_Char16* data;
  MI_Uint32 size;
} MI_ConstChar16A;

typedef struct _MI_ConstDatetimeA {
  MI_CONST MI_Datetime* data;
  MI_Uint32 size;
} MI_ConstDatetimeA;

typedef struct _MI_ConstStringA {
  MI_CONST MI_Char* MI_CONST* data;
  MI_Uint32 size;
} MI_ConstStringA;

typedef struct _MI_ConstReferenceA {
  MI_CONST MI_Instance* MI_CONST* data;
  MI_Uint32 size;
} MI_ConstReferenceA;

typedef struct _MI_ConstInstanceA {
  MI_CONST MI_Instance* MI_CONST* data;
  MI_Uint32 size;
} MI_ConstInstanceA;

typedef union _MI_Value {
  MI_Boolean boolean;
  MI_Uint8 uint8;
  MI_Sint8 sint8;
  MI_Uint16 uint16;
  MI_Sint16 sint16;
  MI_Uint32 uint32;
  MI_Sint32 sint32;
  MI_Uint64 uint64;
  MI_Sint64 sint64;
  MI_Real32 real32;
  MI_Real64 real64;
  MI_Char16 char16;
  MI_Datetime datetime;
  MI_Char* string;
  MI_Instance* instance;
  MI_Instance* reference;
  MI_BooleanA booleana;
  MI_Uint8A uint8a;
  MI_Sint8A sint8a;
  MI_Uint16A uint16a;
  MI_Sint16A sint16a;
  MI_Uint32A uint32a;
  MI_Sint32A sint32a;
  MI_Uint64A uint64a;
  MI_Sint64A sint64a;
  MI_Real32A real32a;
  MI_Real64A real64a;
  MI_Char16A char16a;
  MI_DatetimeA datetimea;
  MI_StringA stringa;
  MI_ReferenceA referencea;
  MI_InstanceA instancea;
  MI_Array array;
} MI_Value;

typedef struct _MI_BooleanField {
  MI_Boolean value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_BooleanField;

typedef struct _MI_Sint8Field {
  MI_Sint8 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Sint8Field;

typedef struct _MI_Uint8Field {
  MI_Uint8 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Uint8Field;

typedef struct _MI_Sint16Field {
  MI_Sint16 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Sint16Field;

typedef struct _MI_Uint16Field {
  MI_Uint16 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Uint16Field;

typedef struct _MI_Sint32Field {
  MI_Sint32 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Sint32Field;

typedef struct _MI_Uint32Field {
  MI_Uint32 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Uint32Field;

typedef struct _MI_Sint64Field {
  MI_Sint64 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Sint64Field;

typedef struct _MI_Uint64Field {
  MI_Uint64 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Uint64Field;

typedef struct _MI_Real32Field {
  MI_Real32 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Real32Field;

typedef struct _MI_Real64Field {
  MI_Real64 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Real64Field;

typedef struct _MI_Char16Field {
  MI_Char16 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Char16Field;

typedef struct _MI_DatetimeField {
  MI_Datetime value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_DatetimeField;

typedef struct _MI_StringField {
  MI_Char* value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_StringField;

typedef struct _MI_ReferenceField {
  MI_Instance* value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ReferenceField;

typedef struct _MI_InstanceField {
  MI_Instance* value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_InstanceField;

typedef struct _MI_BooleanAField {
  MI_BooleanA value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_BooleanAField;

typedef struct _MI_Uint8AField {
  MI_Uint8A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Uint8AField;

typedef struct _MI_Sint8AField {
  MI_Sint8A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Sint8AField;

typedef struct _MI_Uint16AField {
  MI_Uint16A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Uint16AField;

typedef struct _MI_Sint16AField {
  MI_Sint16A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Sint16AField;

typedef struct _MI_Uint32AField {
  MI_Uint32A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Uint32AField;

typedef struct _MI_Sint32AField {
  MI_Sint32A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Sint32AField;

typedef struct _MI_Uint64AField {
  MI_Uint64A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Uint64AField;

typedef struct _MI_Sint64AField {
  MI_Sint64A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Sint64AField;

typedef struct _MI_Real32AField {
  MI_Real32A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Real32AField;

typedef struct _MI_Real64AField {
  MI_Real64A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Real64AField;

typedef struct _MI_Char16AField {
  MI_Char16A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_Char16AField;

typedef struct _MI_DatetimeAField {
  MI_DatetimeA value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_DatetimeAField;

typedef struct _MI_StringAField {
  MI_StringA value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_StringAField;

typedef struct _MI_ReferenceAField {
  MI_ReferenceA value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ReferenceAField;

typedef struct _MI_InstanceAField {
  MI_InstanceA value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_InstanceAField;

typedef struct _MI_ArrayField {
  MI_Array value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ArrayField;

typedef struct _MI_ConstBooleanField {
  MI_Boolean value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstBooleanField;

typedef struct _MI_ConstSint8Field {
  MI_Sint8 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstSint8Field;

typedef struct _MI_ConstUint8Field {
  MI_Uint8 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstUint8Field;

typedef struct _MI_ConstSint16Field {
  MI_Sint16 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstSint16Field;

typedef struct _MI_ConstUint16Field {
  MI_Uint16 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstUint16Field;

typedef struct _MI_ConstSint32Field {
  MI_Sint32 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstSint32Field;

typedef struct _MI_ConstUint32Field {
  MI_Uint32 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstUint32Field;

typedef struct _MI_ConstSint64Field {
  MI_Sint64 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstSint64Field;

typedef struct _MI_ConstUint64Field {
  MI_Uint64 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstUint64Field;

typedef struct _MI_ConstReal32Field {
  MI_Real32 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstReal32Field;

typedef struct _MI_ConstReal64Field {
  MI_Real64 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstReal64Field;

typedef struct _MI_ConstChar16Field {
  MI_Char16 value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstChar16Field;

typedef struct _MI_ConstDatetimeField {
  MI_Datetime value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstDatetimeField;

typedef struct _MI_ConstStringField {
  MI_CONST MI_Char* value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstStringField;

typedef struct _MI_ConstReferenceField {
  MI_CONST MI_Instance* value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstReferenceField;

typedef struct _MI_ConstInstanceField {
  MI_CONST MI_Instance* value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstInstanceField;

typedef struct _MI_ConstBooleanAField {
  MI_ConstBooleanA value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstBooleanAField;

typedef struct _MI_ConstUint8AField {
  MI_ConstUint8A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstUint8AField;

typedef struct _MI_ConstSint8AField {
  MI_ConstSint8A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstSint8AField;

typedef struct _MI_ConstUint16AField {
  MI_ConstUint16A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstUint16AField;

typedef struct _MI_ConstSint16AField {
  MI_ConstSint16A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstSint16AField;

typedef struct _MI_ConstUint32AField {
  MI_ConstUint32A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstUint32AField;

typedef struct _MI_ConstSint32AField {
  MI_ConstSint32A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstSint32AField;

typedef struct _MI_ConstUint64AField {
  MI_ConstUint64A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstUint64AField;

typedef struct _MI_ConstSint64AField {
  MI_ConstSint64A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstSint64AField;

typedef struct _MI_ConstReal32AField {
  MI_ConstReal32A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstReal32AField;

typedef struct _MI_ConstReal64AField {
  MI_ConstReal64A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstReal64AField;

typedef struct _MI_ConstChar16AField {
  MI_ConstChar16A value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstChar16AField;

typedef struct _MI_ConstDatetimeAField {
  MI_ConstDatetimeA value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstDatetimeAField;

typedef struct _MI_ConstStringAField {
  MI_ConstStringA value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstStringAField;

typedef struct _MI_ConstReferenceAField {
  MI_ConstReferenceA value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstReferenceAField;

typedef struct _MI_ConstInstanceAField {
  MI_ConstInstanceA value;
  MI_Boolean exists;
  MI_Uint8 flags;
} MI_ConstInstanceAField;

struct _MI_ServerFT {
  MI_Result (MI_CALL *GetVersion)(MI_Uint32* version);
  MI_Result (MI_CALL *GetSystemName)(const MI_Char** systemName);
};

struct _MI_Server {
  const MI_ServerFT* serverFT;
  const MI_ContextFT* contextFT;
  const MI_InstanceFT* instanceFT;
  const MI_PropertySetFT* propertySetFT;
  const MI_FilterFT* filterFT;
};

MI_Result MI_CALL MI_Server_GetVersion(MI_Uint32* version);
MI_Result MI_CALL MI_Server_GetSystemName(const MI_Char** systemName);

struct _MI_FilterFT {
  MI_Result (MI_CALL *Evaluate)(const MI_Filter* self, const MI_Instance* instance, MI_Boolean* result);
  MI_Result (MI_CALL *GetExpression)(const MI_Filter* self, const MI_Char** queryLang, const MI_Char** queryExpr);
};

struct _MI_Filter {
  const MI_FilterFT* ft;
  ptrdiff_t reserved[3];
};

MI_INLINE MI_Result MI_INLINE_CALL MI_Filter_Evaluate(const MI_Filter* self, const MI_Instance* instance, MI_Boolean* result) {
  if (self && self->ft) {
    return self->ft->Evaluate(self, instance, result);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Filter_GetExpression(const MI_Filter* self, const MI_Char** queryLang, const MI_Char** queryExpr) {
  if (self && self->ft) {
    return self->ft->GetExpression(self, queryLang, queryExpr);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

struct _MI_PropertySetFT {
  MI_Result (MI_CALL *GetElementCount)(const MI_PropertySet* self, MI_Uint32* count);
  MI_Result (MI_CALL *ContainsElement)(const MI_PropertySet* self, const MI_Char* name, MI_Boolean* flag);
  MI_Result (MI_CALL *AddElement)(MI_PropertySet* self, const MI_Char* name);
  MI_Result (MI_CALL *GetElementAt)(const MI_PropertySet* self, MI_Uint32 index, const MI_Char** name);
  MI_Result (MI_CALL *Clear)(MI_PropertySet* self);
  MI_Result (MI_CALL *Destruct)(MI_PropertySet* self);
  MI_Result (MI_CALL *Delete)(MI_PropertySet* self);
  MI_Result (MI_CALL *Clone)(const MI_PropertySet* self, MI_PropertySet** newPropertySet);
};

struct _MI_PropertySet {
  const MI_PropertySetFT* ft;
  ptrdiff_t reserved[3];
};

MI_INLINE MI_Result MI_INLINE_CALL MI_PropertySet_GetElementCount(const MI_PropertySet* self, MI_Uint32* count) {
  if (self && self->ft) {
    return self->ft->GetElementCount(self, count);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_PropertySet_ContainsElement(const MI_PropertySet* self, const MI_Char* name, MI_Boolean* flag) {
  if (self && self->ft) {
    return self->ft->ContainsElement(self, name, flag);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_PropertySet_AddElement(MI_PropertySet* self, const MI_Char* name) {
  if (self && self->ft) {
    return self->ft->AddElement(self, name);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_PropertySet_GetElementAt(const MI_PropertySet* self, MI_Uint32 index, const MI_Char** name) {
  if (self && self->ft) {
    return self->ft->GetElementAt(self, index, name);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_PropertySet_Clear(MI_PropertySet* self) {
  if (self && self->ft) {
    return self->ft->Clear(self);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_PropertySet_Destruct(MI_PropertySet* self) {
  if (self && self->ft) {
    return self->ft->Destruct(self);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_PropertySet_Delete(MI_PropertySet* self) {
  if (self && self->ft) {
    return self->ft->Delete(self);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_PropertySet_Clone(const MI_PropertySet* self, MI_PropertySet** newPropertySet) {
  if (self && self->ft) {
    return self->ft->Clone(self, newPropertySet);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

typedef struct _MI_ObjectDecl {
  MI_Uint32 flags;
  MI_Uint32 code;
  MI_CONST MI_Char* name;
  MI_Qualifier MI_CONST* MI_CONST* qualifiers;
  MI_Uint32 numQualifiers;
  struct _MI_PropertyDecl MI_CONST* MI_CONST* properties;
  MI_Uint32 numProperties;
  MI_Uint32 size;
} MI_ObjectDecl;

struct _MI_ClassDecl {
  MI_Uint32 flags;
  MI_Uint32 code;
  MI_CONST MI_Char* name;
  struct _MI_Qualifier MI_CONST* MI_CONST* qualifiers;
  MI_Uint32 numQualifiers;
  struct _MI_PropertyDecl MI_CONST* MI_CONST* properties;
  MI_Uint32 numProperties;
  MI_Uint32 size;
  MI_CONST MI_Char* superClass;
  MI_ClassDecl MI_CONST* superClassDecl;
  struct _MI_MethodDecl MI_CONST* MI_CONST* methods;
  MI_Uint32 numMethods;
  struct _MI_SchemaDecl MI_CONST* schema;
  MI_CONST MI_ProviderFT* providerFT;
  MI_Class *owningClass;
};

typedef struct _MI_FeatureDecl {
  MI_Uint32 flags;
  MI_Uint32 code;
  MI_CONST MI_Char* name;
  MI_Qualifier MI_CONST* MI_CONST * qualifiers;
  MI_Uint32 numQualifiers;
} MI_FeatureDecl;

typedef struct _MI_ParameterDecl {
  MI_Uint32 flags;
  MI_Uint32 code;
  MI_CONST MI_Char* name;
  MI_Qualifier MI_CONST* MI_CONST* qualifiers;
  MI_Uint32 numQualifiers;
  MI_Uint32 type;
  MI_CONST MI_Char* className;
  MI_Uint32 subscript;
  MI_Uint32 offset;
} MI_ParameterDecl;

typedef struct _MI_PropertyDecl {
  MI_Uint32 flags;
  MI_Uint32 code;
  MI_CONST MI_Char* name;
  MI_Qualifier MI_CONST* MI_CONST* qualifiers;
  MI_Uint32 numQualifiers;
  MI_Uint32 type;
  MI_CONST MI_Char* className;
  MI_Uint32 subscript;
  MI_Uint32 offset;
  MI_CONST MI_Char* origin;
  MI_CONST MI_Char* propagator;
  MI_CONST void* value;
} MI_PropertyDecl;

typedef void (MI_CALL *MI_MethodDecl_Invoke)(void* self, MI_Context* context, const MI_Char* nameSpace, const MI_Char* className, const MI_Char* methodName, const MI_Instance* instanceName, const MI_Instance* parameters);

typedef struct _MI_MethodDecl {
  MI_Uint32 flags;
  MI_Uint32 code;
  MI_CONST MI_Char* name;
  struct _MI_Qualifier MI_CONST* MI_CONST* qualifiers;
  MI_Uint32 numQualifiers;
  struct _MI_ParameterDecl MI_CONST* MI_CONST* parameters;
  MI_Uint32 numParameters;
  MI_Uint32 size;
  MI_Uint32 returnType;
  MI_CONST MI_Char* origin;
  MI_CONST MI_Char* propagator;
  struct _MI_SchemaDecl MI_CONST* schema;
  MI_MethodDecl_Invoke function;
} MI_MethodDecl;

typedef struct _MI_QualifierDecl {
  MI_CONST MI_Char* name;
  MI_Uint32 type;
  MI_Uint32 scope;
  MI_Uint32 flavor;
  MI_Uint32 subscript;
  MI_CONST void* value;
} MI_QualifierDecl;

struct _MI_Qualifier {
  MI_CONST MI_Char* name;
  MI_Uint32 type;
  MI_Uint32 flavor;
  MI_CONST void* value;
};

typedef struct _MI_SchemaDecl {
  MI_QualifierDecl MI_CONST* MI_CONST* qualifierDecls;
  MI_Uint32 numQualifierDecls;
  MI_ClassDecl MI_CONST* MI_CONST* classDecls;
  MI_Uint32 numClassDecls;
} MI_SchemaDecl;

typedef struct _MI_Module_Self MI_Module_Self;

typedef void (MI_CALL *MI_ProviderFT_Load)(void** self, MI_Module_Self* selfModule, MI_Context* context);
typedef void (MI_CALL *MI_ProviderFT_Unload)(void* self, MI_Context* context);
typedef void (MI_CALL *MI_ProviderFT_GetInstance)(void* self, MI_Context* context, const MI_Char* nameSpace, const MI_Char* className, const MI_Instance* instanceName, const MI_PropertySet* propertySet);
typedef void (MI_CALL *MI_ProviderFT_EnumerateInstances)(void* self, MI_Context* context, const MI_Char* nameSpace, const MI_Char* className, const MI_PropertySet* propertySet, MI_Boolean keysOnly, const MI_Filter* filter);
typedef void (MI_CALL *MI_ProviderFT_CreateInstance)(void* self, MI_Context* context, const MI_Char* nameSpace, const MI_Char* className, const MI_Instance* newInstance);
typedef void (MI_CALL *MI_ProviderFT_ModifyInstance)(void* self, MI_Context* context, const MI_Char* nameSpace, const MI_Char* className, const MI_Instance* modifiedInstance, const MI_PropertySet* propertySet);
typedef void (MI_CALL *MI_ProviderFT_DeleteInstance)(void* self, MI_Context* context, const MI_Char* nameSpace, const MI_Char* className, const MI_Instance* instanceName);
typedef void (MI_CALL *MI_ProviderFT_AssociatorInstances)(void* self, MI_Context* context, const MI_Char* nameSpace, const MI_Char* className, const MI_Instance* instanceName, const MI_Char* resultClass, const MI_Char* role, const MI_Char* resultRole, const MI_PropertySet* propertySet, MI_Boolean keysOnly, const MI_Filter* filter);
typedef void (MI_CALL *MI_ProviderFT_ReferenceInstances)(void* self, MI_Context* context, const MI_Char* nameSpace, const MI_Char* className, const MI_Instance* instanceName, const MI_Char* role, const MI_PropertySet* propertySet, MI_Boolean keysOnly, const MI_Filter* filter);
typedef void (MI_CALL *MI_ProviderFT_EnableIndications)(void* self, MI_Context* indicationsContext, const MI_Char* nameSpace, const MI_Char* className);
typedef void (MI_CALL *MI_ProviderFT_DisableIndications)(void* self, MI_Context* indicationsContext, const MI_Char* nameSpace, const MI_Char* className);
typedef void (MI_CALL *MI_ProviderFT_Subscribe)(void* self, MI_Context* context, const MI_Char* nameSpace, const MI_Char* className, const MI_Filter* filter, const MI_Char* bookmark, MI_Uint64 subscriptionID, void** subscriptionSelf);
typedef void (MI_CALL *MI_ProviderFT_Unsubscribe)(void* self, MI_Context* context, const MI_Char* nameSpace, const MI_Char* className, MI_Uint64 subscriptionID, void* subscriptionSelf);
typedef void (MI_CALL *MI_ProviderFT_Invoke)(void* self, MI_Context* context, const MI_Char* nameSpace, const MI_Char* className, const MI_Char* methodName, const MI_Instance* instanceName, const MI_Instance* inputParameters);

struct _MI_ProviderFT {
  MI_ProviderFT_Load Load;
  MI_ProviderFT_Unload Unload;
  MI_ProviderFT_GetInstance GetInstance;
  MI_ProviderFT_EnumerateInstances EnumerateInstances;
  MI_ProviderFT_CreateInstance CreateInstance;
  MI_ProviderFT_ModifyInstance ModifyInstance;
  MI_ProviderFT_DeleteInstance DeleteInstance;
  MI_ProviderFT_AssociatorInstances AssociatorInstances;
  MI_ProviderFT_ReferenceInstances ReferenceInstances;
  MI_ProviderFT_EnableIndications EnableIndications;
  MI_ProviderFT_DisableIndications DisableIndications;
  MI_ProviderFT_Subscribe Subscribe;
  MI_ProviderFT_Unsubscribe Unsubscribe;
  MI_ProviderFT_Invoke Invoke;
};

#define MI_MODULE_FLAG_STANDARD_QUALIFIERS (1 << 0)
#define MI_MODULE_FLAG_DESCRIPTIONS (1 << 1)
#define MI_MODULE_FLAG_VALUES (1 << 2)
#define MI_MODULE_FLAG_MAPPING_STRINGS (1 << 3)
#define MI_MODULE_FLAG_BOOLEANS (1 << 4)
#define MI_MODULE_FLAG_CPLUSPLUS (1 << 5)
#define MI_MODULE_FLAG_LOCALIZED (1 << 6)
#define MI_MODULE_FLAG_FILTER_SUPPORT (1 << 7)

typedef void (MI_CALL *MI_Module_Load)(MI_Module_Self** self, MI_Context* context);
typedef void (MI_CALL *MI_Module_Unload)(MI_Module_Self* self, MI_Context* context);

typedef struct _MI_Module {
  MI_Uint32 version;
  MI_Uint32 generatorVersion;
  MI_Uint32 flags;
  MI_Uint32 charSize;
  MI_SchemaDecl* schemaDecl;
  MI_Module_Load Load;
  MI_Module_Unload Unload;
  const MI_ProviderFT* dynamicProviderFT;
} MI_Module;

struct _MI_InstanceFT {
  MI_Result (MI_CALL *Clone)(const MI_Instance* self, MI_Instance** newInstance);
  MI_Result (MI_CALL *Destruct)(MI_Instance* self);
  MI_Result (MI_CALL *Delete)(MI_Instance* self);
  MI_Result (MI_CALL *IsA)(const MI_Instance* self, const MI_ClassDecl* classDecl, MI_Boolean* flag);
  MI_Result (MI_CALL *GetClassName)(const MI_Instance* self, const MI_Char** className);
  MI_Result (MI_CALL *SetNameSpace)(MI_Instance* self, const MI_Char* nameSpace);
  MI_Result (MI_CALL *GetNameSpace)(const MI_Instance* self, const MI_Char** nameSpace);
  MI_Result (MI_CALL *GetElementCount)(const MI_Instance* self, MI_Uint32* count);
  MI_Result (MI_CALL *AddElement)(MI_Instance* self, const MI_Char* name, const MI_Value* value, MI_Type type, MI_Uint32 flags);
  MI_Result (MI_CALL *SetElement)(MI_Instance* self, const MI_Char* name, const MI_Value* value, MI_Type type, MI_Uint32 flags);
  MI_Result (MI_CALL *SetElementAt)(MI_Instance* self, MI_Uint32 index, const MI_Value* value, MI_Type type, MI_Uint32 flags);
  MI_Result (MI_CALL *GetElement)(const MI_Instance* self, const MI_Char* name, MI_Value* value, MI_Type* type, MI_Uint32* flags, MI_Uint32* index);
  MI_Result (MI_CALL *GetElementAt)(const MI_Instance* self, MI_Uint32 index, const MI_Char** name, MI_Value* value, MI_Type* type, MI_Uint32* flags);
  MI_Result (MI_CALL *ClearElement)(MI_Instance* self, const MI_Char* name);
  MI_Result (MI_CALL *ClearElementAt)(MI_Instance* self, MI_Uint32 index);
  MI_Result (MI_CALL *GetServerName)(const MI_Instance* self, const MI_Char** name);
  MI_Result (MI_CALL *SetServerName)(MI_Instance* self, const MI_Char* name);
  MI_Result (MI_CALL *GetClass)(const MI_Instance* self, MI_Class** instanceClass);
};

struct _MI_InstanceExFT {
  MI_InstanceFT parent;
  MI_Result (MI_CALL *Normalize)(MI_Instance** self);
};

struct _MI_Instance {
  const MI_InstanceFT* ft;
  const MI_ClassDecl* classDecl;
  const MI_Char* serverName;
  const MI_Char* nameSpace;
  ptrdiff_t reserved[4];
};

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_Clone(const MI_Instance* self, MI_Instance** newInstance) {
  if (self && self->ft) {
    return self->ft->Clone(self, newInstance);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_Destruct(MI_Instance* self) {
  if (self && self->ft) {
    return self->ft->Destruct(self);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_Delete(MI_Instance* self) {
  if (self && self->ft) {
    return self->ft->Delete(self);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_IsA(const MI_Instance* self, const MI_ClassDecl* classDecl, MI_Boolean* flag) {
  if (self && self->ft) {
    return self->ft->IsA(self, classDecl, flag);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_GetClassName(const MI_Instance* self, const MI_Char** className) {
  if (self && self->ft) {
    return self->ft->GetClassName(self, className);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_SetNameSpace(MI_Instance* self, const MI_Char* nameSpace) {
  if (self && self->ft) {
    return self->ft->SetNameSpace(self, nameSpace);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_GetNameSpace(const MI_Instance* self, const MI_Char** nameSpace) {
  if (self && self->ft) {
    return self->ft->GetNameSpace(self, nameSpace);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_GetElementCount(const MI_Instance* self, MI_Uint32* count) {
  if (self && self->ft) {
    return self->ft->GetElementCount(self, count);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_AddElement(MI_Instance* self, const MI_Char* name, const MI_Value* value, MI_Type type, MI_Uint32 flags) {
  if (self && self->ft) {
    return self->ft->AddElement(self, name, value, type, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_SetElementAt(MI_Instance* self, MI_Uint32 index, const MI_Value* value, MI_Type type, MI_Uint32 flags) {
  if (self && self->ft) {
    return self->ft->SetElementAt(self, index, value, type, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_SetElement(MI_Instance* self, const MI_Char* name, const MI_Value* value, MI_Type type, MI_Uint32 flags) {
  if (self && self->ft) {
    return self->ft->SetElement(self, name, value, type, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_GetElement(const MI_Instance* self, const MI_Char* name, MI_Value* value, MI_Type* type, MI_Uint32* flags, MI_Uint32* index) {
  if (self && self->ft) {
    return self->ft->GetElement(self, name, value, type, flags, index);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_GetElementAt(const MI_Instance* self, MI_Uint32 index, const MI_Char** name, MI_Value* value, MI_Type* type, MI_Uint32* flags) {
  if (self && self->ft) {
    return self->ft->GetElementAt(self, index, name, value, type, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_ClearElement(MI_Instance* self, const MI_Char* name) {
  if (self && self->ft) {
    return self->ft->ClearElement(self, name);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_ClearElementAt(MI_Instance* self, MI_Uint32 index) {
  if (self && self->ft) {
    return self->ft->ClearElementAt(self, index);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_GetServerName(const MI_Instance* self, const MI_Char** name) {
  if (self && self->ft) {
    return self->ft->GetServerName(self, name);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_SetServerName(MI_Instance* self, const MI_Char* name) {
  if (self && self->ft) {
    return self->ft->SetServerName(self, name);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_GetClass(const MI_Instance* self, MI_Class** instanceClass) {
  if (self && self->ft) {
    return self->ft->GetClass(self, instanceClass);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Instance_Normalize(MI_Instance** self) {
  MI_Instance* inst = *self;
  if (inst && inst->ft) {
    if (inst->classDecl->flags & MI_FLAG_EXTENDED) {
      MI_InstanceExFT* ft = (MI_InstanceExFT*)inst->ft;
      return ft->Normalize(self);
    } else {
      return MI_RESULT_OK;
    }
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

#define MI_MAX_LOCALE_SIZE 128

typedef enum _MI_LocaleType {
  MI_LOCALE_TYPE_REQUESTED_UI,
  MI_LOCALE_TYPE_REQUESTED_DATA,
  MI_LOCALE_TYPE_CLOSEST_UI,
  MI_LOCALE_TYPE_CLOSEST_DATA
} MI_LocaleType;

typedef enum _MI_CancellationReason {
  MI_REASON_NONE,
  MI_REASON_TIMEOUT,
  MI_REASON_SHUTDOWN,
  MI_REASON_SERVICESTOP
} MI_CancellationReason;

typedef void (MI_CALL *MI_CancelCallback)(MI_CancellationReason reason, void* callbackData);

#define MI_WRITEMESSAGE_CHANNEL_WARNING 0
#define MI_WRITEMESSAGE_CHANNEL_VERBOSE 1
#define MI_WRITEMESSAGE_CHANNEL_DEBUG 2

#define MI_RESULT_TYPE_MI MI_T("MI")
#define MI_RESULT_TYPE_HRESULT MI_T("HRESULT")
#define MI_RESULT_TYPE_WIN32 MI_T("WIN32")
#define MI_RESULT_TYPE_ERRNO MI_T("ERRNO")

struct _MI_ContextFT {
  MI_Result (MI_CALL *PostResult)(MI_Context* context, MI_Result result);
  MI_Result (MI_CALL *PostInstance)(MI_Context* context, const MI_Instance* instance);
  MI_Result (MI_CALL *PostIndication)(MI_Context* context, const MI_Instance* indication, MI_Uint32 subscriptionIDCount, const MI_Char* bookmark);
  MI_Result (MI_CALL *ConstructInstance)(MI_Context* context, const MI_ClassDecl* classDecl, MI_Instance* instance);
  MI_Result (MI_CALL *ConstructParameters)(MI_Context* context, const MI_MethodDecl* methodDecl, MI_Instance* instance);
  MI_Result (MI_CALL *NewInstance)(MI_Context* context, const MI_ClassDecl* classDecl, MI_Instance** instance);
  MI_Result (MI_CALL *NewDynamicInstance)(MI_Context* context, const MI_Char* className, MI_Uint32 flags, MI_Instance** instance);
  MI_Result (MI_CALL *NewParameters)(MI_Context* context, const MI_MethodDecl* methodDecl, MI_Instance** instance);
  MI_Result (MI_CALL *Canceled)(const MI_Context* context, MI_Boolean* flag);
  MI_Result (MI_CALL *GetLocale)(const MI_Context* context, MI_LocaleType localeType, MI_Char locale[MI_MAX_LOCALE_SIZE]);
  MI_Result (MI_CALL *RegisterCancel)(MI_Context* context, MI_CancelCallback callback, void* callbackData);
  MI_Result (MI_CALL *RequestUnload)(MI_Context* context);
  MI_Result (MI_CALL *RefuseUnload)(MI_Context* context);
  MI_Result (MI_CALL *GetLocalSession)(const MI_Context* context, MI_Session* session);
  MI_Result (MI_CALL *SetStringOption)(MI_Context* context, const MI_Char* name, const MI_Char* value);
  MI_Result (MI_CALL *GetStringOption)(MI_Context* context, const MI_Char* name, const MI_Char** value);
  MI_Result (MI_CALL *GetNumberOption)(MI_Context* context, const MI_Char *name, MI_Uint32* value);
  MI_Result (MI_CALL *GetCustomOption)(MI_Context* context, const MI_Char* name, MI_Type* valueType, MI_Value* value);
  MI_Result (MI_CALL *GetCustomOptionCount)(MI_Context* context, MI_Uint32* count);
  MI_Result (MI_CALL *GetCustomOptionAt)(MI_Context* context, MI_Uint32 index, const MI_Char** name, MI_Type* valueType, MI_Value* value);
  MI_Result (MI_CALL *WriteMessage)(MI_Context* context, MI_Uint32 channel, const MI_Char* message);
  MI_Result (MI_CALL *WriteProgress)(MI_Context* context, const MI_Char* activity, const MI_Char* currentOperation, const MI_Char* statusDescription, MI_Uint32 percentComplete, MI_Uint32 secondsRemaining);
  MI_Result (MI_CALL *WriteStreamParameter)(MI_Context* context, const MI_Char* name, const MI_Value* value, MI_Type type, MI_Uint32 flags);
  MI_Result (MI_CALL *WriteCimError)(MI_Context* context, const MI_Instance *error, MI_Boolean *flag);
  MI_Result (MI_CALL *PromptUser)(MI_Context* context, const MI_Char* message, MI_PromptType promptType, MI_Boolean* result );
  MI_Result (MI_CALL *ShouldProcess)(MI_Context* context, const MI_Char* target, const MI_Char* action, MI_Boolean* result);
  MI_Result (MI_CALL *ShouldContinue)(MI_Context* context, const MI_Char* message, MI_Boolean* result);
  MI_Result (MI_CALL *PostError)(MI_Context* context, MI_Uint32 resultCode, const MI_Char* resultType, const MI_Char* errorMessage);
  MI_Result (MI_CALL *PostCimError)(MI_Context* context, const MI_Instance *error);
  MI_Result (MI_CALL *WriteError)(MI_Context* context, MI_Uint32 resultCode, const MI_Char* resultType, const MI_Char* errorMessage, MI_Boolean *flag);
};

struct _MI_Context {
  const MI_ContextFT* ft;
  ptrdiff_t reserved[3];
};

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_PostResult(MI_Context* context, MI_Result result) {
  if (context && context->ft) {
    return context->ft->PostResult(context, result);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_PostCimError(MI_Context* context, const MI_Instance *error) {
  if (context && context->ft) {
    return context->ft->PostCimError(context, error);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_PostError(MI_Context* context, MI_Uint32 resultCode, const MI_Char* resultType, const MI_Char* errorMessage) {
  if (context && context->ft) {
    return context->ft->PostError(context, resultCode, resultType, errorMessage);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_PostInstance(MI_Context* context, const MI_Instance* instance) {
  if (context && context->ft) {
    return context->ft->PostInstance(context, instance);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_PostIndication(MI_Context* context, const MI_Instance* indication, MI_Uint32 subscriptionIDCount, const MI_Char* bookmark) {
  if (context && context->ft) {
    return context->ft->PostIndication(context, indication, subscriptionIDCount, bookmark);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_ConstructInstance(MI_Context* context, const MI_ClassDecl* classDecl, MI_Instance* instance) {
  if (context && context->ft) {
    return context->ft->ConstructInstance(context, classDecl, instance);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_ConstructParameters(MI_Context* context, const MI_MethodDecl* methodDecl, MI_Instance* instance) {
  if (context && context->ft) {
    return context->ft->ConstructParameters(context, methodDecl, instance);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_NewInstance(MI_Context* context, const MI_ClassDecl* classDecl, MI_Instance** instance) {
  if (context && context->ft) {
    return context->ft->NewInstance(context, classDecl, instance);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_NewDynamicInstance(MI_Context* context, const MI_Char* className, MI_Uint32 flags, MI_Instance** instance) {
  if (context && context->ft) {
    return context->ft->NewDynamicInstance(context, className, flags, instance);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_NewParameters(MI_Context* context, const MI_MethodDecl* methodDecl, MI_Instance** instance) {
  if (context && context->ft) {
    return context->ft->NewParameters(context, methodDecl, instance);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_Canceled(const MI_Context* context, MI_Boolean* flag) {
  if (context && context->ft) {
    return context->ft->Canceled(context, flag);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_GetLocale(const MI_Context* context, MI_LocaleType localeType, MI_Char locale[MI_MAX_LOCALE_SIZE]) {
  if (locale) {
    locale[0] = L'\0';
  }
  if (context && context->ft) {
    return context->ft->GetLocale(context, localeType, locale);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_RegisterCancel(MI_Context* context, MI_CancelCallback callback, void* callbackData) {
  if (context && context->ft) {
    return context->ft->RegisterCancel(context, callback, callbackData);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_RequestUnload(MI_Context* context) {
  if (context && context->ft) {
    return context->ft->RequestUnload(context);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_RefuseUnload(MI_Context* context) {
  if (context && context->ft) {
    return context->ft->RefuseUnload(context);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
};

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_GetLocalSession(const MI_Context* context, MI_Session* session) {
  if (context && context->ft) {
    return context->ft->GetLocalSession(context, session);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_SetStringOption(MI_Context* context, const MI_Char* name, const MI_Char* value) {
  if (context && context->ft) {
    return context->ft->SetStringOption(context, name, value);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_GetStringOption(MI_Context* context, const MI_Char* name, const MI_Char** value) {
  if (context && context->ft) {
    return context->ft->GetStringOption(context, name, value);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_GetNumberOption(MI_Context* context, const MI_Char* name, MI_Uint32* value) {
  if (context && context->ft) {
    return context->ft->GetNumberOption(context, name, value);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_GetCustomOption(MI_Context* context, const MI_Char* name, MI_Type* valueType, MI_Value* value) {
  if (context && context->ft) {
    return context->ft->GetCustomOption(context, name, valueType,value);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_GetCustomOptionCount(MI_Context* context, MI_Uint32* count) {
  if (context && context->ft) {
    return context->ft->GetCustomOptionCount(context, count);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_GetCustomOptionAt(MI_Context* context, MI_Uint32 index, const MI_Char** name, MI_Type* valueType, MI_Value* value) {
  if (context && context->ft) {
    return context->ft->GetCustomOptionAt(context, index, name, valueType,value);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_ShouldProcess(MI_Context* context, const MI_Char *target, const MI_Char* action, MI_Boolean* flag) {
  if (context && context->ft) {
    return context->ft->ShouldProcess(context, target, action , flag);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_ShouldContinue(MI_Context* context, const MI_Char* message, MI_Boolean* flag) {
  if (context && context->ft) {
    return context->ft->ShouldContinue(context, message, flag);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_PromptUser(MI_Context* context, const MI_Char* message, MI_PromptType promptType, MI_Boolean*flag ) {
  if (context && context->ft) {
    return context->ft->PromptUser(context, message, promptType, flag);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_WriteError(MI_Context* context, MI_Uint32 resultCode, const MI_Char* resultType, const MI_Char* errorMessage, MI_Boolean *flag) {
  if (context && context->ft) {
    return context->ft->WriteError(context, resultCode, resultType, errorMessage, flag);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_WriteCimError(MI_Context* context, const MI_Instance *error, MI_Boolean *flag) {
  if (context && context->ft) {
    return context->ft->WriteCimError(context, error, flag);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_WriteMessage(MI_Context* context, MI_Uint32 channel, const MI_Char* message) {
  if (context && context->ft) {
    return context->ft->WriteMessage(context, channel, message);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_WriteProgress(MI_Context* context, const MI_Char* activity, const MI_Char* currentOperation, const MI_Char* statusDescription, MI_Uint32 percentComplete, MI_Uint32 secondsRemaining) {
  if (context && context->ft) {
    return context->ft->WriteProgress(context, activity, currentOperation, statusDescription, percentComplete, secondsRemaining);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_WriteStreamParameter(MI_Context* self, const MI_Char* name, const MI_Value* value, MI_Type type, MI_Uint32 flags) {
  if (self && self->ft) {
    return self->ft->WriteStreamParameter(self, name, value, type, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_WriteWarning(MI_Context* context, const MI_Char* message) {
  if (context && context->ft) {
    return context->ft->WriteMessage(context, MI_WRITEMESSAGE_CHANNEL_WARNING, message);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_WriteVerbose(MI_Context* context, const MI_Char* message) {
  if (context && context->ft) {
    return context->ft->WriteMessage(context, MI_WRITEMESSAGE_CHANNEL_VERBOSE, message);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Context_WriteDebug(MI_Context* context, const MI_Char* message) {
  if (context && context->ft) {
    return context->ft->WriteMessage(context, MI_WRITEMESSAGE_CHANNEL_DEBUG, message);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

#define MI_InstanceOf(inst) (&(inst)->__instance)

# pragma pack(pop)

#endif /* _MI_h */

#ifndef __MI_C_API_H
#define __MI_C_API_H

#ifndef MI_CALL_VERSION
#define MI_CALL_VERSION 1
#endif

#if (MI_CALL_VERSION > 1)
#error "Unsupported version of MI_CALL_VERSION. This SDK only supports version 1."
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef MI_Module* (MI_MAIN_CALL *MI_MainFunction)(MI_Server* server);

typedef struct _MI_QualifierSet MI_QualifierSet;

typedef struct _MI_QualifierSetFT {
  MI_Result (MI_CALL *GetQualifierCount)(const MI_QualifierSet *self, MI_Uint32 *count);
  MI_Result (MI_CALL *GetQualifierAt)(const MI_QualifierSet *self, MI_Uint32 index, const MI_Char **name, MI_Type *qualifierType, MI_Uint32 *qualifierFlags, MI_Value *qualifierValue);
  MI_Result (MI_CALL *GetQualifier)(const MI_QualifierSet *self, const MI_Char *name, MI_Type *qualifierType, MI_Uint32 *qualifierFlags, MI_Value *qualifierValue, MI_Uint32 *index);
} MI_QualifierSetFT;

struct _MI_QualifierSet {
  MI_Uint64 reserved1;
  ptrdiff_t reserved2;
  const MI_QualifierSetFT *ft;
};

typedef struct _MI_ParameterSet MI_ParameterSet;

typedef struct _MI_ParameterSetFT {
  MI_Result (MI_CALL *GetMethodReturnType)(const MI_ParameterSet *self, MI_Type *returnType, MI_QualifierSet *qualifierSet);
  MI_Result (MI_CALL *GetParameterCount)(const MI_ParameterSet *self, MI_Uint32 *count);
  MI_Result (MI_CALL *GetParameterAt)(const MI_ParameterSet *self, MI_Uint32 index, const MI_Char **name, MI_Type *parameterType, MI_Char **referenceClass, MI_QualifierSet *qualifierSet);
  MI_Result (MI_CALL *GetParameter)(const MI_ParameterSet *self, const MI_Char *name, MI_Type *parameterType, MI_Char **referenceClass, MI_QualifierSet *qualifierSet, MI_Uint32 *index);
} MI_ParameterSetFT;

struct _MI_ParameterSet {
  MI_Uint64 reserved1;
  ptrdiff_t reserved2;
  const MI_ParameterSetFT * ft;
};

typedef struct _MI_ClassFT {
  MI_Result (MI_CALL *GetClassName)(const MI_Class* self, const MI_Char** className);
  MI_Result (MI_CALL *GetNameSpace)(const MI_Class* self, const MI_Char** nameSpace);
  MI_Result (MI_CALL *GetServerName)(const MI_Class* self, const MI_Char** serverName);
  MI_Result (MI_CALL *GetElementCount)(const MI_Class* self, MI_Uint32* count);
  MI_Result (MI_CALL *GetElement)(const MI_Class* self, const MI_Char* name, MI_Value* value, MI_Boolean* valueExists, MI_Type* type, MI_Char **referenceClass, MI_QualifierSet *qualifierSet, MI_Uint32* flags, MI_Uint32* index);
  MI_Result (MI_CALL *GetElementAt)(const MI_Class* self, MI_Uint32 index, const MI_Char** name, MI_Value* value, MI_Boolean* valueExists, MI_Type* type, MI_Char **referenceClass, MI_QualifierSet *qualifierSet, MI_Uint32* flags);
  MI_Result (MI_CALL *GetClassQualifierSet)(const MI_Class* self, MI_QualifierSet *qualifierSet);
  MI_Result (MI_CALL *GetMethodCount)(const MI_Class* self, MI_Uint32* count);
  MI_Result (MI_CALL *GetMethodAt)(const MI_Class *self, MI_Uint32 index, const MI_Char **name, MI_QualifierSet *qualifierSet, MI_ParameterSet *parameterSet);
  MI_Result (MI_CALL *GetMethod)(const MI_Class *self, const MI_Char *name, MI_QualifierSet *qualifierSet, MI_ParameterSet *parameterSet, MI_Uint32 *index);
  MI_Result (MI_CALL *GetParentClassName)(const MI_Class *self, const MI_Char **name);
  MI_Result (MI_CALL *GetParentClass)(const MI_Class *self, MI_Class **parentClass);
  MI_Result (MI_CALL *Delete)(MI_Class* self);
  MI_Result (MI_CALL *Clone)(const MI_Class* self, MI_Class** newClass);
} MI_ClassFT;

struct _MI_Class {
  const MI_ClassFT *ft;
  MI_CONST MI_ClassDecl *classDecl;
  MI_CONST MI_Char *namespaceName;
  MI_CONST MI_Char *serverName;
  ptrdiff_t reserved[4];
};

typedef struct _MI_Application MI_Application;
typedef struct _MI_Session MI_Session;
typedef struct _MI_Operation MI_Operation;
typedef struct _MI_HostedProvider MI_HostedProvider;
typedef struct _MI_DestinationOptions MI_DestinationOptions;
typedef struct _MI_OperationOptions MI_OperationOptions;

typedef enum _MI_OperationCallback_ResponseType {
  MI_OperationCallback_ResponseType_No,
  MI_OperationCallback_ResponseType_Yes,
  MI_OperationCallback_ResponseType_NoToAll,
  MI_OperationCallback_ResponseType_YesToAll
} MI_OperationCallback_ResponseType;

typedef void (MI_CALL *MI_OperationCallback_PromptUser)(MI_Operation *operation, void *callbackContext, const MI_Char *message, MI_PromptType promptType, MI_Result (MI_CALL * promptUserResult)(MI_Operation *operation, MI_OperationCallback_ResponseType response));
typedef void (MI_CALL *MI_OperationCallback_WriteError)(MI_Operation *operation, void *callbackContext, MI_Instance*instance, MI_Result (MI_CALL * writeErrorResult)(MI_Operation *operation, MI_OperationCallback_ResponseType response));

#define MI_WRITEMESSAGE_CHANNEL_WARNING 0
#define MI_WRITEMESSAGE_CHANNEL_VERBOSE 1
#define MI_WRITEMESSAGE_CHANNEL_DEBUG 2

typedef void (MI_CALL *MI_OperationCallback_WriteMessage)(MI_Operation *operation, void *callbackContext, MI_Uint32 channel, const MI_Char *message);
typedef void (MI_CALL *MI_OperationCallback_WriteProgress)(MI_Operation *operation, void *callbackContext, const MI_Char *activity, const MI_Char *currentOperation, const MI_Char *statusDescription, MI_Uint32 percentageComplete, MI_Uint32 secondsRemaining);
typedef void (MI_CALL *MI_OperationCallback_Instance)(MI_Operation *operation, void *callbackContext, const MI_Instance *instance, MI_Boolean moreResults, MI_Result resultCode, const MI_Char *errorString, const MI_Instance *errorDetails, MI_Result (MI_CALL * resultAcknowledgement)(MI_Operation *operation));
typedef void (MI_CALL *MI_OperationCallback_StreamedParameter)(MI_Operation *operation, void *callbackContext, const MI_Char *parameterName, MI_Type resultType, const MI_Value *result, MI_Result (MI_CALL * resultAcknowledgement)(MI_Operation *operation));
typedef void (MI_CALL *MI_OperationCallback_Indication)(MI_Operation *operation, void *callbackContext, const MI_Instance *instance, const MI_Char *bookmark, const MI_Char *machineID, MI_Boolean moreResults, MI_Result resultCode, const MI_Char *errorString, const MI_Instance *errorDetails, MI_Result (MI_CALL * resultAcknowledgement)(MI_Operation *operation));
typedef void (MI_CALL *MI_OperationCallback_Class)(MI_Operation *operation, void *callbackContext, const MI_Class *classResult, MI_Boolean moreResults, MI_Result resultCode, const MI_Char *errorString, const MI_Instance *errorDetails, MI_Result (MI_CALL * resultAcknowledgement)(MI_Operation *operation));

typedef struct _MI_OperationCallbacks {
  void *callbackContext;
  MI_OperationCallback_PromptUser promptUser;
  MI_OperationCallback_WriteError writeError;
  MI_OperationCallback_WriteMessage writeMessage;
  MI_OperationCallback_WriteProgress writeProgress;
  MI_OperationCallback_Instance instanceResult;
  MI_OperationCallback_Indication indicationResult;
  MI_OperationCallback_Class classResult;
  MI_OperationCallback_StreamedParameter streamedParameterResult;
} MI_OperationCallbacks;

#define MI_OPERATIONCALLBACKS_NULL {NULL}

typedef struct _MI_SessionCallbacks {
  void *callbackContext;
  void (MI_CALL *writeMessage)(MI_Application *application, void *callbackContext, MI_Uint32 channel, const MI_Char * message);
  void (MI_CALL *writeError)(MI_Application *application, void *callbackContext, MI_Instance *instance);
} MI_SessionCallbacks;

#define MI_SESSIONCALLBACKS_NULL {NULL}

#define MI_OPERATIONFLAGS_AUTOMATIC_ACK_RESULTS 0x0000
#define MI_OPERATIONFLAGS_MANUAL_ACK_RESULTS 0x0001
#define MI_OPERATIONFLAGS_NO_RTTI 0x0400
#define MI_OPERATIONFLAGS_BASIC_RTTI 0x0002
#define MI_OPERATIONFLAGS_STANDARD_RTTI 0x0800
#define MI_OPERATIONFLAGS_FULL_RTTI 0x0004
#define MI_OPERATIONFLAGS_DEFAULT_RTTI 0
#define MI_OPERATIONFLAGS_NON_LOCALIZED_QUALIFIERS 0x0000
#define MI_OPERATIONFLAGS_LOCALIZED_QUALIFIERS 0x0008
#define MI_OPERATIONFLAGS_NON_EXPENSIVE_PROPERTIES_ONLY 0x0040
#define MI_OPERATIONFLAGS_EXPENSIVE_PROPERTIES 0x0040
#define MI_OPERATIONFLAGS_POLYMORPHISM_DEEP 0x0000
#define MI_OPERATIONFLAGS_POLYMORPHISM_SHALLOW 0x0080
#define MI_OPERATIONFLAGS_POLYMORPHISM_DEEP_BASE_PROPS_ONLY 0x0180
#define MI_OPERATIONFLAGS_REPORT_OPERATION_STARTED 0x0200
#define MI_AUTH_TYPE_DEFAULT MI_T("Default")
#define MI_AUTH_TYPE_NONE MI_T("None")
#define MI_AUTH_TYPE_DIGEST MI_T("Digest")
#define MI_AUTH_TYPE_NEGO_WITH_CREDS MI_T("NegoWithCreds")
#define MI_AUTH_TYPE_NEGO_NO_CREDS MI_T("NegoNoCreds")
#define MI_AUTH_TYPE_BASIC MI_T("Basic")
#define MI_AUTH_TYPE_KERBEROS MI_T("Kerberos")
#define MI_AUTH_TYPE_CLIENT_CERTS MI_T("ClientCerts")
#define MI_AUTH_TYPE_NTLM MI_T("Ntlmdomain")
#if (WINVER >= 0x600)
#define MI_AUTH_TYPE_CREDSSP MI_T("CredSSP")
#endif
#define MI_AUTH_TYPE_ISSUER_CERT MI_T("IssuerCert")

typedef struct _MI_UsernamePasswordCreds {
  const MI_Char *domain;
  const MI_Char *username;
  const MI_Char *password;
} MI_UsernamePasswordCreds;

typedef struct _MI_UserCredentials {
  const MI_Char *authenticationType;
  union {
    MI_UsernamePasswordCreds usernamePassword;
    const MI_Char *certificateThumbprint;
  } credentials;
} MI_UserCredentials;

typedef enum _MI_SubscriptionDeliveryType {
  MI_SubscriptionDeliveryType_Pull = 1,
  MI_SubscriptionDeliveryType_Push = 2
} MI_SubscriptionDeliveryType;

typedef struct _MI_SubscriptionDeliveryOptions MI_SubscriptionDeliveryOptions;

typedef struct _MI_SubscriptionDeliveryOptionsFT {
  MI_Result (MI_CALL *SetString)(MI_SubscriptionDeliveryOptions *options, const MI_Char *optionName, const MI_Char *value, MI_Uint32 flags);
  MI_Result (MI_CALL *SetNumber)(MI_SubscriptionDeliveryOptions *options, const MI_Char *optionName, MI_Uint32 value, MI_Uint32 flags);
  MI_Result (MI_CALL *SetDateTime)(MI_SubscriptionDeliveryOptions *options, const MI_Char *optionName, const MI_Datetime *value, MI_Uint32 flags);
  MI_Result (MI_CALL *SetInterval)(MI_SubscriptionDeliveryOptions *options, const MI_Char *optionName, const MI_Interval *value, MI_Uint32 flags);
  MI_Result (MI_CALL *AddCredentials)(MI_SubscriptionDeliveryOptions *options, const MI_Char *optionName, const MI_UserCredentials *credentials, MI_Uint32 flags);
  MI_Result (MI_CALL *Delete)(MI_SubscriptionDeliveryOptions* self);
  MI_Result (MI_CALL *GetString)(MI_SubscriptionDeliveryOptions *options, const MI_Char *optionName, const MI_Char **value, MI_Uint32 *index, MI_Uint32 *flags);
  MI_Result (MI_CALL *GetNumber)(MI_SubscriptionDeliveryOptions *options, const MI_Char *optionName, MI_Uint32 *value, MI_Uint32 *index, MI_Uint32 *flags);
  MI_Result (MI_CALL *GetDateTime)(MI_SubscriptionDeliveryOptions *options, const MI_Char *optionName, MI_Datetime *value, MI_Uint32 *index, MI_Uint32 *flags);
  MI_Result (MI_CALL *GetInterval)(MI_SubscriptionDeliveryOptions *options, const MI_Char *optionName, MI_Interval *value, MI_Uint32 *index, MI_Uint32 *flags);
  MI_Result (MI_CALL *GetOptionCount)(MI_SubscriptionDeliveryOptions *options, MI_Uint32 *count);
  MI_Result (MI_CALL *GetOptionAt)(MI_SubscriptionDeliveryOptions *options, MI_Uint32 index, const MI_Char **optionName, MI_Value *value, MI_Type *type, MI_Uint32 *flags);
  MI_Result (MI_CALL *GetOption)(MI_SubscriptionDeliveryOptions *options, const MI_Char *optionName, MI_Value *value, MI_Type *type, MI_Uint32 *index, MI_Uint32 *flags);
  MI_Result (MI_CALL *GetCredentialsCount)(MI_SubscriptionDeliveryOptions *options, MI_Uint32 *count);
  MI_Result (MI_CALL *GetCredentialsAt)(MI_SubscriptionDeliveryOptions *options, MI_Uint32 index, const MI_Char **optionName, MI_UserCredentials *credentials, MI_Uint32 *flags);
  MI_Result (MI_CALL *GetCredentialsPasswordAt)(MI_SubscriptionDeliveryOptions *options, MI_Uint32 index, const MI_Char **optionName, MI_Char *password, MI_Uint32 bufferLength, MI_Uint32 *passwordLength, MI_Uint32 *flags);
  MI_Result (MI_CALL *Clone)(const MI_SubscriptionDeliveryOptions* self, MI_SubscriptionDeliveryOptions* newSubscriptionDeliveryOptions);
} MI_SubscriptionDeliveryOptionsFT;

typedef struct _MI_SubscriptionDeliveryOptions {
  MI_Uint64 reserved1;
  ptrdiff_t reserved2;
  const MI_SubscriptionDeliveryOptionsFT * ft;
} MI_SubscriptionDeliveryOptions;

#define MI_SUBSCRIPTIONDELIVERYOPTIONS_NULL { 0, 0, NULL }

typedef struct _MI_Serializer MI_Serializer;
typedef struct _MI_SerializerFT MI_SerializerFT;
typedef struct _MI_Deserializer MI_Deserializer;
typedef struct _MI_DeserializerFT MI_DeserializerFT;

struct _MI_Serializer {
  MI_Uint64 reserved1;
  ptrdiff_t reserved2;
};

struct _MI_Deserializer {
  MI_Uint64 reserved1;
  ptrdiff_t reserved2;
};

struct _MI_SerializerFT {
  MI_Result (MI_CALL *Close)(MI_Serializer *serializer);
  MI_Result (MI_CALL *SerializeClass)(MI_Serializer *serializer, MI_Uint32 flags, const MI_Class *classObject, MI_Uint8 *clientBuffer, MI_Uint32 clientBufferLength, MI_Uint32 *clientBufferNeeded);
  MI_Result (MI_CALL *SerializeInstance)(MI_Serializer *serializer, MI_Uint32 flags, const MI_Instance *instanceObject, MI_Uint8 *clientBuffer, MI_Uint32 clientBufferLength, MI_Uint32 *clientBufferNeeded);
};

typedef MI_Result (MI_CALL *MI_Deserializer_ClassObjectNeeded)(void *context, const MI_Char *serverName, const MI_Char *namespaceName, const MI_Char *className, MI_Class **requestedClassObject);

struct _MI_DeserializerFT {
  MI_Result (MI_CALL *Close)(MI_Deserializer *deserializer);
  MI_Result (MI_CALL *DeserializeClass)(MI_Deserializer *deserializer, MI_Uint32 flags, MI_Uint8 *serializedBuffer, MI_Uint32 serializedBufferLength, MI_Class *parentClass, const MI_Char *serverName, const MI_Char *namespaceName, MI_Deserializer_ClassObjectNeeded classObjectNeeded, void *classObjectNeededContext, MI_Uint32 *serializedBufferRead, MI_Class **classObject, MI_Instance **cimErrorDetails);
  MI_Result (MI_CALL *Class_GetClassName)(MI_Deserializer *deserializer, MI_Uint8 *serializedBuffer, MI_Uint32 serializedBufferLength, MI_Char *className, MI_Uint32 *classNameLength, MI_Instance **cimErrorDetails);
  MI_Result (MI_CALL *Class_GetParentClassName)(MI_Deserializer *deserializer, MI_Uint8 *serializedBuffer, MI_Uint32 serializedBufferLength, MI_Char *parentClassName, MI_Uint32 *parentClassNameLength, MI_Instance **cimErrorDetails);
  MI_Result (MI_CALL *DeserializeInstance)(MI_Deserializer *deserializer, MI_Uint32 flags, MI_Uint8 *serializedBuffer, MI_Uint32 serializedBufferLength, MI_Class **classObjects, MI_Uint32 numberClassObjects, MI_Deserializer_ClassObjectNeeded classObjectNeeded, void *classObjectNeededContext, MI_Uint32 *serializedBufferRead, MI_Instance **instanceObject, MI_Instance **cimErrorDetails);
  MI_Result (MI_CALL *Instance_GetClassName)(MI_Deserializer *deserializer, MI_Uint8 *serializedBuffer, MI_Uint32 serializedBufferLength, MI_Char *className, MI_Uint32 *classNameLength, MI_Instance **cimErrorDetails);
};

typedef struct _MI_ApplicationFT {
  MI_Result (MI_CALL *Close)(MI_Application *application);
  MI_Result (MI_CALL *NewSession)(MI_Application *application, const MI_Char *protocol, const MI_Char *destination, MI_DestinationOptions *options, MI_SessionCallbacks *callbacks, MI_Instance **extendedError, MI_Session *session);
  MI_Result (MI_CALL *NewHostedProvider)(MI_Application *application, const MI_Char *namespaceName, const MI_Char *providerName, MI_MainFunction mi_Main, MI_Instance **extendedError, MI_HostedProvider *provider);
  MI_Result (MI_CALL *NewInstance)(MI_Application *application, const MI_Char *className, const MI_ClassDecl *classRTTI, MI_Instance **instance);
  MI_Result (MI_CALL *NewDestinationOptions)(MI_Application *application, MI_DestinationOptions *options);
  MI_Result (MI_CALL *NewOperationOptions)(MI_Application *application, MI_Boolean customOptionsMustUnderstand, MI_OperationOptions *options);
  MI_Result (MI_CALL *NewSubscriptionDeliveryOptions)(MI_Application *application, MI_SubscriptionDeliveryType deliveryType, MI_SubscriptionDeliveryOptions *deliveryOptions);
  MI_Result (MI_CALL *NewSerializer)(MI_Application *application, MI_Uint32 flags, MI_Char *format, MI_Serializer *serializer);
  MI_Result (MI_CALL *NewDeserializer)(MI_Application *application, MI_Uint32 flags, MI_Char *format, MI_Deserializer *deserializer);
  MI_Result (MI_CALL *NewInstanceFromClass)(MI_Application *application, const MI_Char *className, const MI_Class *classObject, MI_Instance **instance);
  MI_Result (MI_CALL *NewClass)(MI_Application *application, const MI_ClassDecl* classDecl, const MI_Char *namespaceName, const MI_Char *serverName, MI_Class** classObject);
} MI_ApplicationFT;

typedef struct _MI_HostedProviderFT {
  MI_Result (MI_CALL *Close)(MI_HostedProvider *hostedProvider);
  MI_Result (MI_CALL *GetApplication)(MI_HostedProvider *hostedProvider, MI_Application *application);
} MI_HostedProviderFT;

typedef struct _MI_SessionFT {
  MI_Result (MI_CALL *Close)(MI_Session *session, void *completionContext, void (MI_CALL *completionCallback)(void *completionContext));
  MI_Result (MI_CALL *GetApplication)(MI_Session *session, MI_Application *application);
  void (MI_CALL *GetInstance)(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Instance *inboundInstance, MI_OperationCallbacks *callbacks, MI_Operation *operation);
  void (MI_CALL *ModifyInstance)(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Instance *inboundInstance, MI_OperationCallbacks *callbacks, MI_Operation *operation);
  void (MI_CALL *CreateInstance)(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Instance *inboundInstance, MI_OperationCallbacks *callbacks, MI_Operation *operation);
  void (MI_CALL *DeleteInstance)(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Instance *inboundInstance, MI_OperationCallbacks *callbacks, MI_Operation *operation);
  void (MI_CALL *Invoke)(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Char *className, const MI_Char *methodName, const MI_Instance *inboundInstance, const MI_Instance *inboundProperties, MI_OperationCallbacks *callbacks, MI_Operation *operation);
  void (MI_CALL *EnumerateInstances)(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Char *className, MI_Boolean keysOnly, MI_OperationCallbacks *callbacks, MI_Operation *operation);
  void (MI_CALL *QueryInstances)(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Char *queryDialect, const MI_Char *queryExpression, MI_OperationCallbacks *callbacks, MI_Operation *operation);
  void (MI_CALL *AssociatorInstances)(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Instance *instanceKeys, const MI_Char *assocClass, const MI_Char *resultClass, const MI_Char *role, const MI_Char *resultRole, MI_Boolean keysOnly, MI_OperationCallbacks *callbacks, MI_Operation *operation);
  void (MI_CALL *ReferenceInstances)(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Instance *instanceKeys, const MI_Char *resultClass, const MI_Char *role, MI_Boolean keysOnly, MI_OperationCallbacks *callbacks, MI_Operation *operation);
  void (MI_CALL *Subscribe)(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Char *queryDialect, const MI_Char *queryExpression, const MI_SubscriptionDeliveryOptions *deliverOptions, MI_OperationCallbacks *callbacks, MI_Operation *operation);
  void (MI_CALL *GetClass)(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Char *className, MI_OperationCallbacks *callbacks, MI_Operation *operation);
  void (MI_CALL *EnumerateClasses)(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Char *className, MI_Boolean classNamesOnly, MI_OperationCallbacks *callbacks, MI_Operation *operation);
  void (MI_CALL *TestConnection)(MI_Session *session, MI_Uint32 flags, MI_OperationCallbacks *callbacks, MI_Operation *operation);
} MI_SessionFT;

typedef struct _MI_OperationFT {
  MI_Result (MI_CALL *Close)(MI_Operation *operation);
  MI_Result (MI_CALL *Cancel)(MI_Operation *operation, MI_CancellationReason reason);
  MI_Result (MI_CALL *GetSession)(MI_Operation *operation, MI_Session *session);
  MI_Result (MI_CALL *GetInstance)(MI_Operation *operation, const MI_Instance **instance, MI_Boolean *moreResults, MI_Result *result, const MI_Char **errorMessage, const MI_Instance **completionDetails);
  MI_Result (MI_CALL *GetIndication)(MI_Operation *operation, const MI_Instance **instance, const MI_Char **bookmark, const MI_Char **machineID, MI_Boolean *moreResults, MI_Result *result, const MI_Char **errorMessage, const MI_Instance **completionDetails);
  MI_Result (MI_CALL *GetClass)(MI_Operation *operation, const MI_Class **classResult, MI_Boolean *moreResults, MI_Result *result, const MI_Char **errorMessage, const MI_Instance **completionDetails);
} MI_OperationFT;

typedef struct _MI_DestinationOptionsFT {
  void (MI_CALL *Delete)(MI_DestinationOptions *options);
  MI_Result (MI_CALL *SetString)(MI_DestinationOptions *options, const MI_Char *optionName, const MI_Char *value, MI_Uint32 flags);
  MI_Result (MI_CALL *SetNumber)(MI_DestinationOptions *options, const MI_Char *optionName, MI_Uint32 value, MI_Uint32 flags);
  MI_Result (MI_CALL *AddCredentials)(MI_DestinationOptions *options, const MI_Char *optionName, const MI_UserCredentials *credentials, MI_Uint32 flags);
  MI_Result (MI_CALL *GetString)(MI_DestinationOptions *options, const MI_Char *optionName, const MI_Char **value, MI_Uint32 *index, MI_Uint32 *flags);
  MI_Result (MI_CALL *GetNumber)(MI_DestinationOptions *options, const MI_Char *optionName, MI_Uint32 *value, MI_Uint32 *index, MI_Uint32 *flags);
  MI_Result (MI_CALL *GetOptionCount)(MI_DestinationOptions *options, MI_Uint32 *count);
  MI_Result (MI_CALL *GetOptionAt)(MI_DestinationOptions *options, MI_Uint32 index, const MI_Char **optionName, MI_Value *value, MI_Type *type, MI_Uint32 *flags);
  MI_Result (MI_CALL *GetOption)(MI_DestinationOptions *options, const MI_Char *optionName, MI_Value *value, MI_Type *type, MI_Uint32 *index, MI_Uint32 *flags);
  MI_Result (MI_CALL *GetCredentialsCount)(MI_DestinationOptions *options, MI_Uint32 *count);
  MI_Result (MI_CALL *GetCredentialsAt)(MI_DestinationOptions *options, MI_Uint32 index, const MI_Char **optionName, MI_UserCredentials *credentials, MI_Uint32 *flags);
  MI_Result (MI_CALL *GetCredentialsPasswordAt)(MI_DestinationOptions *options, MI_Uint32 index, const MI_Char **optionName, MI_Char *password, MI_Uint32 bufferLength, MI_Uint32 *passwordLength, MI_Uint32 *flags);
  MI_Result (MI_CALL *Clone)(const MI_DestinationOptions* self, MI_DestinationOptions* newDestinationOptions);
  MI_Result (MI_CALL *SetInterval)(MI_DestinationOptions *options, const MI_Char *optionName, const MI_Interval *value, MI_Uint32 flags);
  MI_Result (MI_CALL *GetInterval)(MI_DestinationOptions *options, const MI_Char *optionName, MI_Interval *value, MI_Uint32 *index, MI_Uint32 *flags);
} MI_DestinationOptionsFT;

typedef struct _MI_OperationOptionsFT {
  void (MI_CALL *Delete)(MI_OperationOptions *options);
  MI_Result (MI_CALL *SetString)(MI_OperationOptions *options, const MI_Char *optionName, const MI_Char *value, MI_Uint32 flags);
  MI_Result (MI_CALL *SetNumber)(MI_OperationOptions *options, const MI_Char *optionName, MI_Uint32 value, MI_Uint32 flags);
  MI_Result (MI_CALL *SetCustomOption)(MI_OperationOptions *options, const MI_Char *optionName, MI_Type valueType, const MI_Value *value, MI_Boolean mustComply, MI_Uint32 flags);
  MI_Result (MI_CALL *GetString)(MI_OperationOptions *options, const MI_Char *optionName, const MI_Char **value, MI_Uint32 *index, MI_Uint32 *flags);
  MI_Result (MI_CALL *GetNumber)(MI_OperationOptions *options, const MI_Char *optionName, MI_Uint32 *value, MI_Uint32 *index, MI_Uint32 *flags);
  MI_Result (MI_CALL *GetOptionCount)(MI_OperationOptions *options, MI_Uint32 *count);
  MI_Result (MI_CALL *GetOptionAt)(MI_OperationOptions *options, MI_Uint32 index, const MI_Char **optionName, MI_Value *value, MI_Type *type, MI_Uint32 *flags);
  MI_Result (MI_CALL *GetOption)(MI_OperationOptions *options, const MI_Char *optionName, MI_Value *value, MI_Type *type, MI_Uint32 *index, MI_Uint32 *flags);
  MI_Result (MI_CALL *GetEnabledChannels)(MI_OperationOptions *options, const MI_Char *optionName, MI_Uint32 *channels, MI_Uint32 bufferLength, MI_Uint32 *channelCount, MI_Uint32 *flags);
  MI_Result (MI_CALL *Clone)(const MI_OperationOptions* self, MI_OperationOptions* newOperationOptions);
  MI_Result (MI_CALL *SetInterval)(MI_OperationOptions *options, const MI_Char *optionName, const MI_Interval *value, MI_Uint32 flags);
  MI_Result (MI_CALL *GetInterval)(MI_OperationOptions *options, const MI_Char *optionName, MI_Interval *value, MI_Uint32 *index, MI_Uint32 *flags);
} MI_OperationOptionsFT;

struct _MI_Application {
  MI_Uint64 reserved1;
  ptrdiff_t reserved2;
  const MI_ApplicationFT *ft;
};

#define MI_APPLICATION_NULL { 0, 0, NULL }

struct _MI_Session {
  MI_Uint64 reserved1;
  ptrdiff_t reserved2;
  const MI_SessionFT *ft;
};

#define MI_SESSION_NULL { 0, 0, NULL }

struct _MI_Operation {
  MI_Uint64 reserved1;
  ptrdiff_t reserved2;
  const MI_OperationFT *ft;
};

#define MI_OPERATION_NULL { 0, 0, NULL }

struct _MI_HostedProvider {
  MI_Uint64 reserved1;
  ptrdiff_t reserved2;
  const MI_HostedProviderFT *ft;
};

#define MI_HOSTEDPROVIDER_NULL { 0, 0, NULL }

struct _MI_DestinationOptions {
  MI_Uint64 reserved1;
  ptrdiff_t reserved2;
  const MI_DestinationOptionsFT *ft;
};

#define MI_DESTINATIONOPTIONS_NULL { 0, 0, NULL }

struct _MI_OperationOptions {
  MI_Uint64 reserved1;
  ptrdiff_t reserved2;
  const MI_OperationOptionsFT *ft;
};

#define MI_OPERATIONOPTIONS_NULL { 0, 0, NULL }

typedef struct _MI_UtilitiesFT {
  MI_ErrorCategory (MI_CALL *MapErrorToMiErrorCategory)(MI_Char *errorType, MI_Uint32 error);
  MI_Result (MI_CALL *CimErrorFromErrorCode)(MI_Uint32 error, const MI_Char *errorType, const MI_Char* errorMessage, MI_Instance **cimError);
} MI_UtilitiesFT;

typedef struct _MI_ClientFT_V1 {
  const MI_ApplicationFT *applicationFT;
  const MI_SessionFT *sessionFT;
  const MI_OperationFT *operationFT;
  const MI_HostedProviderFT *hostedProviderFT;
  const MI_SerializerFT *serializerFT;
  const MI_DeserializerFT *deserializerFT;
  const MI_SubscriptionDeliveryOptionsFT *subscribeDeliveryOptionsFT;
  const MI_DestinationOptionsFT *destinationOptionsFT;
  const MI_OperationOptionsFT *operationOptionsFT;
  const MI_UtilitiesFT *utilitiesFT;
} MI_ClientFT_V1;

#ifndef _MANAGED_PURE
__declspec(dllimport) const MI_ClientFT_V1 *mi_clientFT_V1;
#endif

#if (MI_CALL_VERSION == 1)
#define mi_clientFT mi_clientFT_V1
#endif

MI_Result MI_MAIN_CALL MI_Application_InitializeV1(MI_Uint32 flags, const MI_Char *applicationID, MI_Instance **extendedError, MI_Application *application);

#if MI_CALL_VERSION == 1
#define MI_Application_Initialize MI_Application_InitializeV1
#endif

MI_INLINE MI_Result MI_Application_Close(MI_Application *application) {
  if (application && application->ft) {
    return application->ft->Close(application);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Application_NewInstance(MI_Application *application, const MI_Char *className, const MI_ClassDecl *classRTTI, MI_Instance **instance) {
  if (application && application->ft) {
    return application->ft->NewInstance(application, className, classRTTI, instance);
  } else {
    if (instance) {
      *instance = NULL;
    }
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Application_NewInstanceFromClass(MI_Application *application, const MI_Char *className, const MI_Class *classObject, MI_Instance **instance) {
  if (application && application->ft) {
    return application->ft->NewInstanceFromClass(application, className, classObject, instance);
  } else {
    if (instance) {
      *instance = NULL;
    }
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Application_NewClass(MI_Application *application, const MI_ClassDecl* classDecl, const MI_Char *namespaceName, const MI_Char *serverName, MI_Class** classObject) {
  if (application && application->ft) {
    return application->ft->NewClass(application, classDecl, namespaceName, serverName, classObject);
  } else {
    if (classObject) {
      *classObject = NULL;
    }
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Application_NewParameterSet(MI_Application *application, const MI_ClassDecl *classRTTI, MI_Instance **instance) {
  if (application && application->ft) {
    return application->ft->NewInstance(application, MI_T("Parameters"), classRTTI, instance);
  } else {
    if (instance) {
      *instance = NULL;
    }
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Application_NewDestinationOptions(MI_Application *application, MI_DestinationOptions *options) {
  if (application && application->ft) {
    return application->ft->NewDestinationOptions(application, options);
  } else {
    if (options) {
      memset(options, 0, sizeof(MI_DestinationOptions));
    }
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Application_NewOperationOptions(MI_Application *application, MI_Boolean mustUnderstand, MI_OperationOptions *options) {
  if (application && application->ft) {
    return application->ft->NewOperationOptions(application, mustUnderstand, options);
  } else {
    if (options) {
      memset(options, 0, sizeof(MI_OperationOptions));
    }
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Application_NewSubscriptionDeliveryOptions(MI_Application *application, MI_SubscriptionDeliveryType deliveryType, MI_SubscriptionDeliveryOptions *deliveryOptions) {
  if (application && application->ft) {
    return application->ft->NewSubscriptionDeliveryOptions(application, deliveryType, deliveryOptions);
  } else {
    if (deliveryOptions) {
      memset(deliveryOptions, 0, sizeof(MI_SubscriptionDeliveryOptions));
    }
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Application_NewSession(MI_Application *application, const MI_Char *protocol, const MI_Char *destination, MI_DestinationOptions *options, MI_SessionCallbacks *callbacks, MI_Instance **extendedError, MI_Session *session) {
  if (application && application->ft) {
    return application->ft->NewSession(application, protocol, destination, options, callbacks, extendedError, session);
  } else {
    if (session) {
      memset(session, 0, sizeof(MI_Session));
    }
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Application_NewHostedProvider(MI_Application *application, const MI_Char *namespaceName, const MI_Char *providerName, MI_MainFunction mi_Main, MI_Instance **extendedError, MI_HostedProvider *hostedProvider) {
  if (application && application->ft) {
    return application->ft->NewHostedProvider(application, namespaceName, providerName, mi_Main, extendedError, hostedProvider);
  } else {
    if (hostedProvider) {
      memset(hostedProvider, 0, sizeof(MI_HostedProvider));
    }
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Application_NewSerializer(MI_Application *application, MI_Uint32 flags, MI_Char *format, MI_Serializer *serializer) {
  if (application && application->ft) {
    return application->ft->NewSerializer(application, flags, format, serializer);
  } else {
    if (serializer) {
      memset(serializer, 0, sizeof(MI_Serializer));
    }
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Application_NewDeserializer(MI_Application *application, MI_Uint32 flags, MI_Char *format, MI_Deserializer *deserializer) {
  if (application && application->ft) {
    return application->ft->NewDeserializer(application, flags, format, deserializer);
  } else {
    if (deserializer) {
      memset(deserializer, 0, sizeof(MI_Deserializer));
    }
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_HostedProvider_Close(MI_HostedProvider *hostedProvider) {
  if (hostedProvider && hostedProvider->ft) {
    return hostedProvider->ft->Close(hostedProvider);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_HostedProvider_GetApplication(MI_HostedProvider *hostedProvider, MI_Application *application) {
  if (hostedProvider && hostedProvider->ft) {
    return hostedProvider->ft->GetApplication(hostedProvider, application);
  } else if (application) {
    memset(application, 0, sizeof(MI_Application));
  }
  return MI_RESULT_INVALID_PARAMETER;
}

MI_INLINE MI_Result MI_Session_Close(MI_Session *session, void *completionContext, void (MI_CALL *completionCallback)(void *completionContext)) {
  if (session && session->ft) {
    return session->ft->Close(session, completionContext, completionCallback);
  } else if (completionCallback) {
    completionCallback(completionContext);
    return MI_RESULT_OK;
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Session_GetApplication(MI_Session *session, MI_Application *application) {
  if (session && session->ft) {
    return session->ft->GetApplication(session, application);
  }
  if (application) {
    memset(application, 0, sizeof(MI_Application));
  }
  return MI_RESULT_INVALID_PARAMETER;
}

MI_INLINE void MI_Session_GetInstance(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Instance *inboundInstance, MI_OperationCallbacks *callbacks, MI_Operation *operation) {
  if (session && session->ft) {
    session->ft->GetInstance(session, flags, options, namespaceName, inboundInstance, callbacks, operation);
  } else {
    if (operation) {
      memset(operation, 0, sizeof(*operation));
    }
    if (callbacks && callbacks->instanceResult) {
      callbacks->instanceResult(NULL, callbacks->callbackContext, NULL, MI_FALSE, MI_RESULT_INVALID_PARAMETER, NULL, NULL, NULL);
    }
  }
}

MI_INLINE void MI_Session_ModifyInstance(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Instance *inboundInstance, MI_OperationCallbacks *callbacks, MI_Operation *operation) {
  if (session && session->ft) {
    session->ft->ModifyInstance(session, flags, options, namespaceName, inboundInstance, callbacks, operation);
  } else {
    if (operation) {
      memset(operation, 0, sizeof(*operation));
    }
    if (callbacks && callbacks->instanceResult) {
      callbacks->instanceResult(NULL, callbacks->callbackContext, NULL, MI_FALSE, MI_RESULT_INVALID_PARAMETER, NULL, NULL, NULL);
    }
  }
}

MI_INLINE void MI_Session_CreateInstance(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Instance *inboundInstance, MI_OperationCallbacks *callbacks, MI_Operation *operation) {
  if (session && session->ft) {
    session->ft->CreateInstance(session, flags, options, namespaceName, inboundInstance, callbacks, operation);
  } else {
    if (operation) {
      memset(operation, 0, sizeof(*operation));
    }
    if (callbacks && callbacks->instanceResult) {
      callbacks->instanceResult(NULL, callbacks->callbackContext, NULL, MI_FALSE, MI_RESULT_INVALID_PARAMETER, NULL, NULL, NULL);
    }
  }
}

MI_INLINE void MI_Session_DeleteInstance(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Instance *inboundInstance, MI_OperationCallbacks *callbacks, MI_Operation *operation) {
  if (session && session->ft) {
    session->ft->DeleteInstance(session, flags, options, namespaceName, inboundInstance, callbacks, operation);
  } else {
    if (operation) {
      memset(operation, 0, sizeof(*operation));
    }
    if (callbacks && callbacks->instanceResult) {
      callbacks->instanceResult(NULL, callbacks->callbackContext, NULL, MI_FALSE, MI_RESULT_INVALID_PARAMETER, NULL, NULL, NULL);
    }
  }
}

MI_INLINE void MI_Session_Invoke(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Char *className, const MI_Char *methodName, const MI_Instance *inboundInstance, const MI_Instance *inboundProperties, MI_OperationCallbacks *callbacks, MI_Operation *operation) {
  if (session && session->ft) {
    session->ft->Invoke(session, flags, options, namespaceName, className, methodName, inboundInstance, inboundProperties, callbacks, operation);
  } else {
    if (operation) {
      memset(operation, 0, sizeof(*operation));
    }
    if (callbacks && callbacks->instanceResult) {
      callbacks->instanceResult(NULL, callbacks->callbackContext, NULL, MI_FALSE, MI_RESULT_INVALID_PARAMETER, NULL, NULL, NULL);
    }
  }
}

MI_INLINE void MI_Session_EnumerateInstances(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Char *className, MI_Boolean keysOnly, MI_OperationCallbacks *callbacks, MI_Operation *operation) {
  if (session && session->ft) {
    session->ft->EnumerateInstances(session, flags, options, namespaceName, className, keysOnly, callbacks, operation);
  } else {
    if (operation) {
      memset(operation, 0, sizeof(*operation));
    }
    if (callbacks && callbacks->instanceResult) {
      callbacks->instanceResult(NULL, callbacks->callbackContext, NULL, MI_FALSE, MI_RESULT_INVALID_PARAMETER, NULL, NULL, NULL);
    }
  }
}

MI_INLINE void MI_Session_QueryInstances(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Char *queryDialect, const MI_Char *queryExpression, MI_OperationCallbacks *callbacks, MI_Operation *operation) {
  if (session && session->ft) {
    session->ft->QueryInstances(session, flags, options, namespaceName, queryDialect, queryExpression, callbacks, operation);
  } else {
    if (operation) {
      memset(operation, 0, sizeof(*operation));
    }
    if (callbacks && callbacks->instanceResult) {
      callbacks->instanceResult(NULL, callbacks->callbackContext, NULL, MI_FALSE, MI_RESULT_INVALID_PARAMETER, NULL, NULL, NULL);
    }
  }
}

MI_INLINE void MI_Session_AssociatorInstances(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Instance *instanceKey, const MI_Char *assocClass, const MI_Char *resultClass, const MI_Char *role, const MI_Char *resultRole, MI_Boolean keysOnly, MI_OperationCallbacks *callbacks, MI_Operation *operation) {
  if (session && session->ft) {
    session->ft->AssociatorInstances(session, flags, options, namespaceName, instanceKey, assocClass, resultClass, role, resultRole, keysOnly, callbacks, operation);
  } else {
    if (operation) {
      memset(operation, 0, sizeof(*operation));
    }
    if (callbacks && callbacks->instanceResult) {
      callbacks->instanceResult(NULL, callbacks->callbackContext, NULL, MI_FALSE, MI_RESULT_INVALID_PARAMETER, NULL, NULL, NULL);
    }
  }
}

MI_INLINE void MI_Session_ReferenceInstances(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Instance *instanceKey, const MI_Char *resultClass, const MI_Char *role, MI_Boolean keysOnly, MI_OperationCallbacks *callbacks, MI_Operation *operation) {
  if (session && session->ft) {
    session->ft->ReferenceInstances(session, flags, options, namespaceName, instanceKey, resultClass, role, keysOnly, callbacks, operation);
  } else {
    if (operation) {
      memset(operation, 0, sizeof(*operation));
    }
    if (callbacks && callbacks->instanceResult) {
      callbacks->instanceResult(NULL, callbacks->callbackContext, NULL, MI_FALSE, MI_RESULT_INVALID_PARAMETER, NULL, NULL, NULL);
    }
  }
}

MI_INLINE void MI_Session_Subscribe(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Char *queryDialect, const MI_Char *queryExpression, const MI_SubscriptionDeliveryOptions *deliverOptions, MI_OperationCallbacks *callbacks, MI_Operation *operation) {
  if (session && session->ft) {
    session->ft->Subscribe(session, flags, options, namespaceName, queryDialect, queryExpression, deliverOptions, callbacks, operation);
  } else {
    if (operation) {
      memset(operation, 0, sizeof(*operation));
    }
    if (callbacks && callbacks->indicationResult) {
      callbacks->indicationResult(NULL, callbacks->callbackContext, NULL, NULL, NULL, MI_FALSE, MI_RESULT_INVALID_PARAMETER, NULL, NULL, NULL);
    }
  }
}

MI_INLINE void MI_Session_GetClass(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Char *className, MI_OperationCallbacks *callbacks, MI_Operation *operation) {
  if (session && session->ft) {
    session->ft->GetClass(session, flags, options, namespaceName, className, callbacks, operation);
  } else {
    if (operation) {
      memset(operation, 0, sizeof(*operation));
    }
    if (callbacks && callbacks->classResult) {
      callbacks->classResult(NULL, callbacks->callbackContext, NULL, MI_FALSE, MI_RESULT_INVALID_PARAMETER, NULL, NULL, NULL);
    }
  }
}

MI_INLINE void MI_Session_EnumerateClasses(MI_Session *session, MI_Uint32 flags, MI_OperationOptions *options, const MI_Char *namespaceName, const MI_Char *className, MI_Boolean classNamesOnly, MI_OperationCallbacks *callbacks, MI_Operation *operation) {
  if (session && session->ft) {
    session->ft->EnumerateClasses(session, flags, options, namespaceName, className, classNamesOnly, callbacks, operation);
  } else {
    if (operation) {
      memset(operation, 0, sizeof(*operation));
    }
    if (callbacks && callbacks->classResult) {
      callbacks->classResult(NULL, callbacks->callbackContext, NULL, MI_FALSE, MI_RESULT_INVALID_PARAMETER, NULL, NULL, NULL);
    }
  }
}

MI_INLINE void MI_Session_TestConnection(MI_Session *session, MI_Uint32 flags, MI_OperationCallbacks *callbacks, MI_Operation *operation) {
  if (session && session->ft) {
    session->ft->TestConnection(session, flags, callbacks, operation);
  } else {
    if (operation) {
      memset(operation, 0, sizeof(*operation));
    }
    if (callbacks && callbacks->instanceResult) {
      callbacks->instanceResult(NULL, callbacks->callbackContext, NULL, MI_FALSE, MI_RESULT_INVALID_PARAMETER, NULL, NULL, NULL);
    }
  }
}

MI_INLINE MI_Result MI_Operation_GetInstance(MI_Operation *operation, const MI_Instance **instance, MI_Boolean *moreResults, MI_Result *result, const MI_Char **errorMessage, const MI_Instance **completionDetails) {
  if (operation && operation->ft) {
    return operation->ft->GetInstance(operation, instance, moreResults, result, errorMessage, completionDetails);
  }
  if (result)
    *result = MI_RESULT_INVALID_PARAMETER;
  if (moreResults)
    *moreResults = MI_FALSE;
  return MI_RESULT_INVALID_PARAMETER;
}

MI_INLINE MI_Result MI_Operation_GetIndication(MI_Operation *operation, const MI_Instance **instance, const MI_Char **bookmark, const MI_Char **machineID, MI_Boolean *moreResults, MI_Result *result, const MI_Char **errorMessage, const MI_Instance **completionDetails) {
  if (operation && operation->ft) {
    return operation->ft->GetIndication(operation, instance, bookmark, machineID, moreResults, result, errorMessage, completionDetails);
  }
  if (result)
    *result = MI_RESULT_INVALID_PARAMETER;
  if (moreResults)
    *moreResults = MI_FALSE;
  return  MI_RESULT_INVALID_PARAMETER;
}

MI_INLINE MI_Result MI_Operation_GetClass(MI_Operation *operation, const MI_Class **classResult, MI_Boolean *moreResults, MI_Result *result, const MI_Char **errorMessage, const MI_Instance **completionDetails) {
  if (operation && operation->ft) {
    return operation->ft->GetClass(operation, classResult, moreResults, result, errorMessage, completionDetails);
  }
  if (result)
    *result = MI_RESULT_INVALID_PARAMETER;
  if (moreResults)
    *moreResults = MI_FALSE;
  return MI_RESULT_INVALID_PARAMETER;
}

MI_INLINE MI_Result MI_Operation_Close(MI_Operation *operation) {
  if (operation && operation->ft) {
    return operation->ft->Close(operation);
  }
  return MI_RESULT_INVALID_PARAMETER;
}

MI_INLINE MI_Result MI_Operation_Cancel(MI_Operation *operation, MI_CancellationReason reason) {
  if (operation && operation->ft) {
    return operation->ft->Cancel(operation, reason);
  }
  return MI_RESULT_INVALID_PARAMETER;
}

MI_INLINE MI_Result MI_Operation_GetSession(MI_Operation *operation, MI_Session *session) {
  if (session) {
    memset(session, 0, sizeof(MI_Session));
  }
  if (operation && operation->ft) {
    return operation->ft->GetSession(operation, session);
  }
  return MI_RESULT_INVALID_PARAMETER;
}

MI_INLINE void MI_DestinationOptions_Delete(MI_DestinationOptions *options) {
  if (options && options->ft) {
    options->ft->Delete(options);
  }
}

MI_INLINE MI_Result MI_DestinationOptions_SetTimeout(MI_DestinationOptions *options, const MI_Interval *timeout) {
  if (options && options->ft) {
    return options->ft->SetInterval(options, MI_T("__MI_DESTINATIONOPTIONS_TIMEOUT"), timeout, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetTimeout(MI_DestinationOptions *options, MI_Interval *timeout) {
  if (options && options->ft) {
    return options->ft->GetInterval(options, MI_T("__MI_DESTINATIONOPTIONS_TIMEOUT"), timeout, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_SetCertCACheck(MI_DestinationOptions *options, MI_Boolean check) {
  if (options && options->ft) {
    return options->ft->SetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_CERT_CA_CHECK"), check, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetCertCACheck(MI_DestinationOptions *options, MI_Boolean *check) {
  if (options && options->ft) {
    MI_Uint32 value;
    MI_Result result = options->ft->GetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_CERT_CA_CHECK"), &value, 0, 0);
    if (result == MI_RESULT_OK)
      *check = (MI_Boolean) value;
    return result;
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_SetCertCNCheck(MI_DestinationOptions *options, MI_Boolean check) {
  if (options && options->ft) {
    return options->ft->SetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_CERT_CN_CHECK"), check, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetCertCNCheck(MI_DestinationOptions *options, MI_Boolean *check) {
  if (options && options->ft) {
    MI_Uint32 value;
    MI_Result result = options->ft->GetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_CERT_CN_CHECK"), &value, 0, 0);
    if (result == MI_RESULT_OK)
      *check = (MI_Boolean) value;
    return result;
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_SetCertRevocationCheck(MI_DestinationOptions *options, MI_Boolean check) {
  if (options && options->ft) {
    return options->ft->SetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_CERT_REVOCATION_CHECK"), check, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetCertRevocationCheck(MI_DestinationOptions *options, MI_Boolean *check) {
  if (options && options->ft) {
    MI_Uint32 value;
    MI_Result result = options->ft->GetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_CERT_REVOCATION_CHECK"), &value, 0, 0);
    if (result == MI_RESULT_OK)
      *check = (MI_Boolean) value;
    return result;
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_SetPacketPrivacy(MI_DestinationOptions *options, MI_Boolean privacy) {
  if (options && options->ft) {
    return options->ft->SetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_PACKET_PRIVACY"), privacy, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetPacketPrivacy(MI_DestinationOptions *options, MI_Boolean *privacy) {
  if (options && options->ft) {
    MI_Uint32 value;
    MI_Result result = options->ft->GetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_PACKET_PRIVACY"), &value, 0, 0);
    if (result == MI_RESULT_OK)
      *privacy = (MI_Boolean) value;
    return result;
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_SetPacketIntegrity(MI_DestinationOptions *options, MI_Boolean integrity) {
  if (options && options->ft) {
    return options->ft->SetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_PACKET_INTEGRITY"), integrity, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetPacketIntegrity(MI_DestinationOptions *options, MI_Boolean *integrity) {
  if (options && options->ft) {
    MI_Uint32 value;
    MI_Result result = options->ft->GetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_PACKET_INTEGRITY"), &value, 0, 0);
    if (result == MI_RESULT_OK)
      *integrity = (MI_Boolean) value;
    return result;
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

#define MI_DESTINATIONOPTIONS_PACKET_ENCODING_DEFAULT MI_T("default")
#define MI_DESTINATIONOPTIONS_PACKET_ENCODING_UTF8 MI_T("UTF8")
#define MI_DESTINATIONOPTIONS_PACKET_ENCODING_UTF16 MI_T("UTF16")

MI_INLINE MI_Result MI_DestinationOptions_SetPacketEncoding(MI_DestinationOptions *options, const MI_Char *encoding) {
  if (options && options->ft) {
    return options->ft->SetString(options, MI_T("__MI_DESTINATIONOPTIONS_PACKET_ENCODING"), encoding, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetPacketEncoding(MI_DestinationOptions *options, const MI_Char **encoding) {
  if (options && options->ft) {
    return options->ft->GetString(options, MI_T("__MI_DESTINATIONOPTIONS_PACKET_ENCODING"), encoding, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_SetDataLocale(MI_DestinationOptions *options, const MI_Char *locale) {
  if (options && options->ft) {
    return options->ft->SetString(options, MI_T("__MI_DESTINATIONOPTIONS_DATA_LOCALE"), locale, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetDataLocale(MI_DestinationOptions *options, const MI_Char **locale) {
  if (options && options->ft) {
    return options->ft->GetString(options, MI_T("__MI_DESTINATIONOPTIONS_DATA_LOCALE"), locale, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_SetUILocale(MI_DestinationOptions *options, const MI_Char *locale) {
  if (options && options->ft) {
    return options->ft->SetString(options, MI_T("__MI_DESTINATIONOPTIONS_UI_LOCALE"), locale, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetUILocale(MI_DestinationOptions *options, const MI_Char **locale) {
  if (options && options->ft) {
    return options->ft->GetString(options, MI_T("__MI_DESTINATIONOPTIONS_UI_LOCALE"), locale, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_SetMaxEnvelopeSize(MI_DestinationOptions *options, MI_Uint32 sizeInKB) {
  if (options && options->ft) {
    return options->ft->SetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_MAX_ENVELOPE_SIZE"), sizeInKB, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetMaxEnvelopeSize(MI_DestinationOptions *options, MI_Uint32 *sizeInKB) {
  if (options && options->ft) {
    return options->ft->GetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_MAX_ENVELOPE_SIZE"), sizeInKB, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_SetEncodePortInSPN(MI_DestinationOptions *options, MI_Boolean encodePort) {
  if (options && options->ft) {
    return options->ft->SetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_ENCODE_PORT_IN_SPN"), encodePort, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetEncodePortInSPN(MI_DestinationOptions *options, MI_Boolean *encodePort) {
  if (options && options->ft) {
    MI_Uint32 value;
    MI_Result result = options->ft->GetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_ENCODE_PORT_IN_SPN"), &value, 0, 0);
    if (result == MI_RESULT_OK)
      *encodePort = (MI_Boolean) value;
    return result;
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_SetHttpUrlPrefix(MI_DestinationOptions *options, const MI_Char *prefix) {
  if (options && options->ft) {
    return options->ft->SetString(options, MI_T("__MI_DESTINATIONOPTIONS_HTTP_URL_PREFIX"), prefix, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetHttpUrlPrefix(MI_DestinationOptions *options, const MI_Char **prefix) {
  if (options && options->ft) {
    return options->ft->GetString(options, MI_T("__MI_DESTINATIONOPTIONS_HTTP_URL_PREFIX"), prefix, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_SetDestinationPort(MI_DestinationOptions *options, MI_Uint32 port) {
  if (options && options->ft) {
    return options->ft->SetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_DESTINATION_PORT"), port, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetDestinationPort(MI_DestinationOptions *options, MI_Uint32 *port) {
  if (options && options->ft) {
    return options->ft->GetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_DESTINATION_PORT"), port, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

#define MI_DESTINATIONOPTIONS_TRANSPORT_HTTP MI_T("HTTP")
#define MI_DESTINATIONOPTIONS_TRANPSORT_HTTPS MI_T("HTTPS")

MI_INLINE MI_Result MI_DestinationOptions_SetTransport(MI_DestinationOptions *options, const MI_Char *transport) {
  if (options && options->ft) {
    return options->ft->SetString(options, MI_T("__MI_DESTINATIONOPTIONS_TRANSPORT"), transport, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetTransport(MI_DestinationOptions *options, const MI_Char **transport) {
  if (options && options->ft) {
    return options->ft->GetString(options, MI_T("__MI_DESTINATIONOPTIONS_TRANSPORT"), transport, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

#define MI_DESTINATIONOPTIONS_PROXY_TYPE_IE MI_T("IE")
#define MI_DESTINATIONOPTIONS_PROXY_TYPE_WINHTTP MI_T("WinHTTP")
#define MI_DESTINATIONOPTIONS_PROXY_TYPE_AUTO MI_T("Auto")
#define MI_DESTINATIONOPTIONS_PROXY_TYPE_NONE MI_T("None")

MI_INLINE MI_Result MI_DestinationOptions_SetProxyType(MI_DestinationOptions *options, const MI_Char *proxyType) {
  if (options && options->ft) {
    return options->ft->SetString(options, MI_T("__MI_DESTINATIONOPTIONS_PROXY_TYPE"), proxyType, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetProxyType(MI_DestinationOptions *options, const MI_Char **proxyType) {
  if (options && options->ft) {
    return options->ft->GetString(options, MI_T("__MI_DESTINATIONOPTIONS_PROXY_TYPE"), proxyType, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_AddProxyCredentials(MI_DestinationOptions *options, const MI_UserCredentials *credentials) {
  if (options && options->ft) {
    return options->ft->AddCredentials(options, MI_T("__MI_DESTINATIONOPTIONS_PROXY_CREDENTIALS"), credentials, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_AddDestinationCredentials(MI_DestinationOptions *options, const MI_UserCredentials *credentials) {
  if (options && options->ft) {
    return options->ft->AddCredentials(options, MI_T("__MI_DESTINATIONOPTIONS_DESTINATION_CREDENTIALS"), credentials, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

typedef enum _MI_DestinationOptions_ImpersonationType {
  MI_DestinationOptions_ImpersonationType_Default = 0,
  MI_DestinationOptions_ImpersonationType_None = 1,
  MI_DestinationOptions_ImpersonationType_Identify = 2,
  MI_DestinationOptions_ImpersonationType_Impersonate = 3,
  MI_DestinationOptions_ImpersonationType_Delegate = 4
} MI_DestinationOptions_ImpersonationType;

MI_INLINE MI_Result MI_DestinationOptions_SetImpersonationType(MI_DestinationOptions *options, MI_DestinationOptions_ImpersonationType impersonationType) {
  if (options && options->ft) {
    return options->ft->SetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_IMPERSONATION_TYPE"), impersonationType, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetImpersonationType(MI_DestinationOptions *options, MI_DestinationOptions_ImpersonationType * impersonationType) {
  if (options && options->ft) {
    MI_Uint32 value;
    MI_Result result = options->ft->GetNumber(options, MI_T("__MI_DESTINATIONOPTIONS_IMPERSONATION_TYPE"), &value, 0, 0);
    if (result == MI_RESULT_OK)
      *impersonationType = (MI_DestinationOptions_ImpersonationType) value;
    return result;
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_SetString(MI_DestinationOptions *options, const MI_Char *optionName, const MI_Char *optionValue) {
  if (options && options->ft) {
    return options->ft->SetString(options, optionName, optionValue, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetString(MI_DestinationOptions *options, const MI_Char *optionName, const MI_Char **optionValue, MI_Uint32 *index) {
  if (options && options->ft) {
    return options->ft->GetString(options, optionName, optionValue, index, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_SetNumber(MI_DestinationOptions *options, const MI_Char *optionName, MI_Uint32 optionValue) {
  if (options && options->ft) {
    return options->ft->SetNumber(options, optionName, optionValue, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetNumber(MI_DestinationOptions *options, const MI_Char *optionName, MI_Uint32 *optionValue, MI_Uint32 *index) {
  if (options && options->ft) {
    return options->ft->GetNumber(options, optionName, optionValue, index, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetOptionCount(MI_DestinationOptions *options, MI_Uint32 *count) {
  if (options && options->ft) {
    return options->ft->GetOptionCount(options, count);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetOptionAt(MI_DestinationOptions *options, MI_Uint32 index, const MI_Char **optionName, MI_Value *value, MI_Type *type, MI_Uint32 *flags) {
  if (options && options->ft) {
    return options->ft->GetOptionAt(options, index, optionName, value, type, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetOption(MI_DestinationOptions *options, const MI_Char *optionName, MI_Value *value, MI_Type *type, MI_Uint32 *index, MI_Uint32 *flags) {
  if (options && options->ft) {
    return options->ft->GetOption(options, optionName, value, type, index, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetCredentialsCount(MI_DestinationOptions *options, MI_Uint32 *count) {
  if (options && options->ft) {
    return options->ft->GetCredentialsCount(options, count);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetCredentialsAt(MI_DestinationOptions *options, MI_Uint32 index, const MI_Char **optionName, MI_UserCredentials *credentials, MI_Uint32 *flags) {
  if (options && options->ft) {
    return options->ft->GetCredentialsAt(options, index, optionName, credentials, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_DestinationOptions_GetCredentialsPasswordAt(MI_DestinationOptions *options, MI_Uint32 index, const MI_Char **optionName, MI_Char *password, MI_Uint32 bufferLength, MI_Uint32 *passwordLength, MI_Uint32 *flags) {
  if (options && options->ft) {
    return options->ft->GetCredentialsPasswordAt(options, index, optionName, password, bufferLength, passwordLength, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_DestinationOptions_Clone(const MI_DestinationOptions* self, MI_DestinationOptions* newDestinationOptions) {
  if (self && self->ft) {
    return self->ft->Clone(self, newDestinationOptions);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE void MI_OperationOptions_Delete(MI_OperationOptions *options) {
  if (options && options->ft) {
    options->ft->Delete(options);
  }
}

MI_INLINE MI_Result MI_OperationOptions_SetWriteErrorMode(MI_OperationOptions *options, MI_CallbackMode mode) {
  if (options && options->ft) {
    return options->ft->SetNumber(options, MI_T("__MI_OPERATIONOPTIONS_WRITEERRORMODE"), mode, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_GetWriteErrorMode(MI_OperationOptions *options, MI_CallbackMode *mode) {
  if (options && options->ft) {
    MI_Uint32 value;
    MI_Result result = options->ft->GetNumber(options, MI_T("__MI_OPERATIONOPTIONS_WRITEERRORMODE"), &value, 0, 0);
    if (result == MI_RESULT_OK)
      *mode = (MI_CallbackMode) value;
    return result;
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_SetPromptUserMode(MI_OperationOptions *options, MI_CallbackMode mode) {
  if (options && options->ft) {
    return options->ft->SetNumber(options, MI_T("__MI_OPERATIONOPTIONS_PROMPTUSERMODE"), mode, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_GetPromptUserMode(MI_OperationOptions *options, MI_CallbackMode *mode) {
  if (options && options->ft) {
    MI_Uint32 value;
    MI_Result result = options->ft->GetNumber(options, MI_T("__MI_OPERATIONOPTIONS_PROMPTUSERMODE"), &value, 0, 0);
    if (result == MI_RESULT_OK)
      *mode = (MI_CallbackMode) value;
    return result;
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_SetPromptUserRegularMode(MI_OperationOptions *options, MI_CallbackMode mode, MI_Boolean ackValue) {
  if (options && options->ft) {
    MI_Result result = options->ft->SetNumber(options, MI_T("__MI_OPERATIONOPTIONS_PROMPTUSERMODE"), mode, 0);
    if( result == MI_RESULT_OK)
      return options->ft->SetNumber(options, MI_T("__MI_OPERATIONOPTIONS_PROMPTUSERMODEREGULAR_ACKVALUE"), ackValue, 0);
    else
      return result;
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_GetPromptUserRegularMode(MI_OperationOptions *options, MI_CallbackMode *mode, MI_Boolean *ackValue) {
  if (options && options->ft) {
    MI_Uint32 _mode;
    MI_Result result = options->ft->GetNumber(options, MI_T("__MI_OPERATIONOPTIONS_PROMPTUSERMODE"), &_mode, 0, 0);
    if( result == MI_RESULT_OK) {
      MI_Uint32 _ackValue;
      result = options->ft->GetNumber(options, MI_T("__MI_OPERATIONOPTIONS_PROMPTUSERMODEREGULAR_ACKVALUE"), &_ackValue, 0, 0);
      if( result == MI_RESULT_OK) {
        *mode = (MI_CallbackMode)_mode;
        *ackValue = (MI_Boolean) _ackValue;
      }
    }
    return result;
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_SetProviderArchitecture(MI_OperationOptions *options, MI_ProviderArchitecture architecture, MI_Boolean mustComply) {
  if (options && options->ft) {
    MI_Result result = options->ft->SetNumber(options, MI_T("__MI_OPERATIONOPTIONS_PROVIDER_ARCHITECTURE"), architecture, 0);
    if(result == MI_RESULT_OK)
      return options->ft->SetNumber(options, MI_T("__MI_OPERATIONOPTIONS_REQUIRED_ARCHITECTURE"), mustComply, 0);
    else
      return result;
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_GetProviderArchitecture(MI_OperationOptions *options, MI_ProviderArchitecture *architecture, MI_Boolean *mustComply) {
  if (options && options->ft) {
    MI_Uint32 _architecture;
    MI_Result result = options->ft->GetNumber(options, MI_T("__MI_OPERATIONOPTIONS_PROVIDER_ARCHITECTURE"), &_architecture, 0, 0);
    if(result == MI_RESULT_OK) {
      MI_Uint32 _mustComply;
      result = options->ft->GetNumber(options, MI_T("__MI_OPERATIONOPTIONS_REQUIRED_ARCHITECTURE"), &_mustComply, 0, 0);
      if(result == MI_RESULT_OK) {
        *architecture = (MI_ProviderArchitecture)_architecture;
        *mustComply = (MI_Boolean)_mustComply;
      }
    }
    return result;
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_EnableChannel(MI_OperationOptions *options, MI_Uint32 channel) {
  if (options && options->ft) {
    return options->ft->SetNumber(options, MI_T("__MI_OPERATIONOPTIONS_CHANNEL"), channel, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_DisableChannel(MI_OperationOptions *options, MI_Uint32 channel) {
  if (options && options->ft) {
    return options->ft->SetNumber(options, MI_T("__MI_OPERATIONOPTIONS_CHANNEL"), channel, 1);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_GetEnabledChannels(MI_OperationOptions *options, MI_Uint32 *channels, MI_Uint32 bufferLength, MI_Uint32 *channelCount, MI_Uint32 *flags) {
  if (options && options->ft) {
    return options->ft->GetEnabledChannels(options, MI_T("__MI_OPERATIONOPTIONS_CHANNEL"), channels, bufferLength, channelCount, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_SetTimeout(MI_OperationOptions *options, const MI_Interval *timeout) {
  if (options && options->ft) {
    return options->ft->SetInterval(options, MI_T("__MI_OPERATIONOPTIONS_TIMEOUT"), timeout, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_GetTimeout(MI_OperationOptions *options, MI_Interval *timeout) {
  if (options && options->ft) {
    return options->ft->GetInterval(options, MI_T("__MI_OPERATIONOPTIONS_TIMEOUT"), timeout, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_SetResourceUriPrefix(MI_OperationOptions *options, const MI_Char *ruriPrefix) {
  if (options && options->ft) {
    return options->ft->SetString(options, MI_T("__MI_OPERATIONOPTIONS_RESOURCE_URI_PREFIX"), ruriPrefix, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_GetResourceUriPrefix(MI_OperationOptions *options, const MI_Char **ruriPrefix) {
  if (options && options->ft) {
    return options->ft->GetString(options, MI_T("__MI_OPERATIONOPTIONS_RESOURCE_URI_PREFIX"), ruriPrefix, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_SetResourceUri(MI_OperationOptions *options, const MI_Char *rUri) {
  if (options && options->ft) {
    return options->ft->SetString(options, MI_T("__MI_OPERATIONOPTIONS_RESOURCE_URI"), rUri, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_GetResourceUri(MI_OperationOptions *options, const MI_Char **rUri) {
  if (options && options->ft) {
    return options->ft->GetString(options, MI_T("__MI_OPERATIONOPTIONS_RESOURCE_URI"), rUri, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_SetUseMachineID(MI_OperationOptions *options, MI_Boolean machineID) {
  if (options && options->ft) {
    return options->ft->SetNumber(options, MI_T("__MI_OPERATIONOPTIONS_USE_MACHINE_ID"), machineID, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_GetUseMachineID(MI_OperationOptions *options, MI_Boolean *machineID) {
  if (options && options->ft) {
    MI_Uint32 value;
    MI_Result result = options->ft->GetNumber(options, MI_T("__MI_OPERATIONOPTIONS_USE_MACHINE_ID"), &value, 0, 0);
    if (result == MI_RESULT_OK)
      *machineID = (MI_Boolean) value;
    return result;
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_SetCustomOption(MI_OperationOptions *options, const MI_Char *optionName, MI_Type optionValueType, const MI_Value *optionValue, MI_Boolean mustComply) {
  if (options && options->ft) {
    return options->ft->SetCustomOption(options, optionName, optionValueType, optionValue, mustComply, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_GetOptionCount(MI_OperationOptions *options, MI_Uint32 *count) {
  if (options && options->ft) {
    return options->ft->GetOptionCount(options, count);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_GetOptionAt(MI_OperationOptions *options, MI_Uint32 index, const MI_Char **optionName, MI_Value *value, MI_Type *type, MI_Uint32 *flags) {
  if (options && options->ft) {
    return options->ft->GetOptionAt(options, index, optionName, value, type, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_SetString(MI_OperationOptions *options, const MI_Char *optionName, const MI_Char *value, MI_Uint32 flags) {
  if (options && options->ft) {
    return options->ft->SetString(options, optionName, value, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_GetString(MI_OperationOptions *options, const MI_Char *optionName, const MI_Char **value, MI_Uint32 *index, MI_Uint32 *flags) {
  if (options && options->ft) {
    return options->ft->GetString(options, optionName, value, index, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_SetNumber(MI_OperationOptions *options, const MI_Char *optionName, MI_Uint32 value, MI_Uint32 flags) {
  if (options && options->ft) {
    return options->ft->SetNumber(options, optionName, value, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_GetNumber(MI_OperationOptions *options, const MI_Char *optionName, MI_Uint32 *value, MI_Uint32 *index, MI_Uint32 *flags) {
  if (options && options->ft) {
    return options->ft->GetNumber(options, optionName, value, index, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_OperationOptions_GetOption(MI_OperationOptions *options, const MI_Char *optionName, MI_Value *value, MI_Type *type, MI_Uint32 *index, MI_Uint32 *flags) {
  if (options && options->ft) {
    return options->ft->GetOption(options, optionName, value, type, index, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_OperationOptions_Clone(const MI_OperationOptions* self, MI_OperationOptions* newOperationOptions) {
  if (self && self->ft) {
    return self->ft->Clone(self, newOperationOptions);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Class_GetClassName(const MI_Class* self, const MI_Char** className) {
  if (self && self->ft) {
    return self->ft->GetClassName(self, className);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Class_GetNameSpace(const MI_Class* self, const MI_Char** nameSpace) {
  if (self && self->ft) {
    return self->ft->GetNameSpace(self, nameSpace);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Class_GetServerName(const MI_Class* self, const MI_Char** serverName) {
  if (self && self->ft) {
    return self->ft->GetServerName(self, serverName);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Class_GetElementCount(const MI_Class* self, MI_Uint32* count) {
  if (self && self->ft) {
    return self->ft->GetElementCount(self, count);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Class_GetElement(const MI_Class* self, const MI_Char* name, MI_Value* value, MI_Boolean* valueExists, MI_Type* type, MI_Char **referenceClass, MI_QualifierSet *qualifierSet, MI_Uint32* flags, MI_Uint32* index) {
  if (self && self->ft) {
    return self->ft->GetElement(self, name, value, valueExists, type, referenceClass, qualifierSet, flags, index);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Class_GetElementAt(const MI_Class* self, MI_Uint32 index, const MI_Char** name, MI_Value* value, MI_Boolean* valueExists, MI_Type* type, MI_Char **referenceClass, MI_QualifierSet *qualifierSet, MI_Uint32* flags) {
  if (self && self->ft) {
    return self->ft->GetElementAt(self, index, name, value, valueExists, type, referenceClass, qualifierSet, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Class_GetClassQualifierSet(const MI_Class* self, MI_QualifierSet *qualifierSet) {
  if (self && self->ft) {
    return self->ft->GetClassQualifierSet(self, qualifierSet);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Class_GetMethodCount(const MI_Class* self, MI_Uint32* count) {
  if (self && self->ft) {
    return self->ft->GetMethodCount(self, count);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Class_GetMethodAt(const MI_Class *self, MI_Uint32 index, const MI_Char **name, MI_QualifierSet *qualifierSet, MI_ParameterSet *parameterSet) {
  if (self && self->ft) {
    return self->ft->GetMethodAt(self, index, name, qualifierSet, parameterSet);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Class_GetMethod(const MI_Class *self, const MI_Char *name, MI_QualifierSet *qualifierSet, MI_ParameterSet *parameterSet, MI_Uint32 *index) {
  if (self && self->ft) {
    return self->ft->GetMethod(self, name, qualifierSet, parameterSet, index);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Class_GetParentClassName(const MI_Class *self, const MI_Char **name) {
  if (self && self->ft) {
    return self->ft->GetParentClassName(self, name);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Class_GetParentClass(const MI_Class *self, MI_Class **parentClass) {
  if (self && self->ft) {
    return self->ft->GetParentClass(self, parentClass);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_Class_Delete(MI_Class* self) {
  if (self && self->ft) {
    return self->ft->Delete(self);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_Class_Clone(const MI_Class* self, MI_Class** newClass) {
  if (self && self->ft) {
    return self->ft->Clone(self, newClass);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_ParameterSet_GetMethodReturnType(const MI_ParameterSet *self, MI_Type *returnType, MI_QualifierSet *qualifierSet) {
  if (self && self->ft) {
    return self->ft->GetMethodReturnType(self, returnType, qualifierSet);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_ParameterSet_GetParameterCount(const MI_ParameterSet *self, MI_Uint32 *count) {
  if (self && self->ft) {
    return self->ft->GetParameterCount(self, count);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_ParameterSet_GetParameterAt(const MI_ParameterSet *self, MI_Uint32 index, const MI_Char **name, MI_Type *parameterType, MI_Char **referenceClass, MI_QualifierSet *qualifierSet) {
  if (self && self->ft) {
    return self->ft->GetParameterAt(self, index, name, parameterType, referenceClass, qualifierSet);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_ParameterSet_GetParameter(const MI_ParameterSet *self, const MI_Char *name, MI_Type *parameterType, MI_Char **referenceClass, MI_QualifierSet *qualifierSet, MI_Uint32 *index) {
  if (self && self->ft) {
    return self->ft->GetParameter(self, name, parameterType, referenceClass, qualifierSet, index);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_QualifierSet_GetQualifierCount(const MI_QualifierSet *self, MI_Uint32 *count) {
  if (self && self->ft) {
    return self->ft->GetQualifierCount(self, count);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_QualifierSet_GetQualifierAt(const MI_QualifierSet *self, MI_Uint32 index, const MI_Char **name, MI_Type *qualifierType, MI_Uint32 *qualifierFlags, MI_Value *qualifierValue) {
  if (self && self->ft) {
    return self->ft->GetQualifierAt(self, index, name, qualifierType, qualifierFlags, qualifierValue);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_QualifierSet_GetQualifier(const MI_QualifierSet *self, const MI_Char *name, MI_Type *qualifierType, MI_Uint32 *qualifierFlags, MI_Value *qualifierValue, MI_Uint32 *index) {
  if (self && self->ft) {
    return self->ft->GetQualifier(self, name, qualifierType, qualifierFlags, qualifierValue, index);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_SetMaximumLatency(MI_SubscriptionDeliveryOptions *self, MI_Interval *value) {
  if (self && self->ft) {
    return self->ft->SetInterval(self, MI_T("__MI_SUBSCRIPTIONDELIVERYOPTIONS_SET_MAXIMUM_LATENCY"), value, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetMaximumLatency(MI_SubscriptionDeliveryOptions *self, MI_Interval *value) {
  if (self && self->ft) {
    return self->ft->GetInterval(self, MI_T("__MI_SUBSCRIPTIONDELIVERYOPTIONS_SET_MAXIMUM_LATENCY"), value, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_SetHeartbeatInterval(MI_SubscriptionDeliveryOptions *self, MI_Interval *value) {
  if (self && self->ft) {
    return self->ft->SetInterval(self, MI_T("__MI_SUBSCRIPTIONDELIVERYOPTIONS_SET_HEARTBEAT_INTERVAL"), value, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetHeartbeatInterval(MI_SubscriptionDeliveryOptions *self, MI_Interval *value) {
  if (self && self->ft) {
    return self->ft->GetInterval(self, MI_T("__MI_SUBSCRIPTIONDELIVERYOPTIONS_SET_HEARTBEAT_INTERVAL"), value, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_SetExpirationTime(MI_SubscriptionDeliveryOptions *self, MI_Datetime *value) {
  if (self && self->ft) {
    return self->ft->SetDateTime(self, MI_T("__MI_SUBSCRIPTIONDELIVERYOPTIONS_SET_EXPIRATION_TIME"), value, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetExpirationTime(MI_SubscriptionDeliveryOptions *self, MI_Datetime *value) {
  if (self && self->ft) {
    return self->ft->GetDateTime(self, MI_T("__MI_SUBSCRIPTIONDELIVERYOPTIONS_SET_EXPIRATION_TIME"), value, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

#define MI_SUBSCRIBE_BOOKMARK_OLDEST L"MI_SUBSCRIBE_BOOKMARK_OLDEST"
#define MI_SUBSCRIBE_BOOKMARK_NEWEST L"MI_SUBSCRIBE_BOOKMARK_NEWEST"

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_SetBookmark(MI_SubscriptionDeliveryOptions *self, const MI_Char *value) {
  if (self && self->ft) {
    return self->ft->SetString(self, MI_T("__MI_SUBSCRIPTIONDELIVERYOPTIONS_SET_BOOKMARK"), value, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetBookmark(MI_SubscriptionDeliveryOptions *self, const MI_Char **value) {
  if (self && self->ft) {
    return self->ft->GetString(self, MI_T("__MI_SUBSCRIPTIONDELIVERYOPTIONS_SET_BOOKMARK"), value, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_SetDeliveryDestination(MI_SubscriptionDeliveryOptions *self, const MI_Char *value) {
  if (self && self->ft) {
    return self->ft->SetString(self, MI_T("__MI_SUBSCRIPTIONDELIVERYOPTIONS_SET_DELIVERY_DESTINATION"), value, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetDeliveryDestination(MI_SubscriptionDeliveryOptions *self, const MI_Char **value) {
  if (self && self->ft) {
    return self->ft->GetString(self, MI_T("__MI_SUBSCRIPTIONDELIVERYOPTIONS_SET_DELIVERY_DESTINATION"), value, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_SetDeliveryPortNumber(MI_SubscriptionDeliveryOptions *self, MI_Uint32 value) {
  if (self && self->ft) {
    return self->ft->SetNumber(self, MI_T("__MI_SUBSCRIPTIONDELIVERYOPTIONS_SET_DELIVERY_PORT_NUMBER"), value, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetDeliveryPortNumber(MI_SubscriptionDeliveryOptions *self, MI_Uint32 *value) {
  if (self && self->ft) {
    return self->ft->GetNumber(self, MI_T("__MI_SUBSCRIPTIONDELIVERYOPTIONS_SET_DELIVERY_PORT_NUMBER"), value, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_AddDeliveryCredentials(MI_SubscriptionDeliveryOptions *self, const MI_UserCredentials *value) {
  if (self && self->ft) {
    return self->ft->AddCredentials(self, MI_T("__MI_SUBSCRIPTIONDELIVERYOPTIONS_ADD_DELIVERY_CREDENTIALS"), value, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_SetDeliveryRetryInterval(MI_SubscriptionDeliveryOptions *self, const MI_Interval *value) {
  if (self && self->ft) {
    return self->ft->SetInterval(self, MI_T("__MI_SUBSCRIPTIONDELIVERYOPTIONS_SET_DELIVERY_RETRY_INTERVAL"), value, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetDeliveryRetryInterval(MI_SubscriptionDeliveryOptions *self, MI_Interval *value) {
  if (self && self->ft) {
    return self->ft->GetInterval(self, MI_T("__MI_SUBSCRIPTIONDELIVERYOPTIONS_SET_DELIVERY_RETRY_INTERVAL"), value, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_SetDeliveryRetryAttempts(MI_SubscriptionDeliveryOptions *self, MI_Uint32 value) {
  if (self && self->ft) {
    return self->ft->SetNumber(self, MI_T("__MI_SUBSCRIPTIONDELIVERYOPTIONS_SET_DELIVERY_RETRY_ATTEMPTS"), value, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetDeliveryRetryAttempts(MI_SubscriptionDeliveryOptions *self, MI_Uint32 *value) {
  if (self && self->ft) {
    return self->ft->GetNumber(self, MI_T("__MI_SUBSCRIPTIONDELIVERYOPTIONS_SET_DELIVERY_RETRY_ATTEMPTS"), value, 0, 0);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_Delete(MI_SubscriptionDeliveryOptions* self) {
  if (self && self->ft) {
    return self->ft->Delete(self);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_SetString(MI_SubscriptionDeliveryOptions *self, const MI_Char *optionName, const MI_Char *value, MI_Uint32 flags) {
  if (self && self->ft) {
    return self->ft->SetString(self, optionName, value, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_SetNumber(MI_SubscriptionDeliveryOptions *self, const MI_Char *optionName, MI_Uint32 value, MI_Uint32 flags) {
  if (self && self->ft) {
    return self->ft->SetNumber(self, optionName, value, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_SetDateTime(MI_SubscriptionDeliveryOptions *self, const MI_Char *optionName, const MI_Datetime *value, MI_Uint32 flags) {
  if (self && self->ft) {
    return self->ft->SetDateTime(self, optionName, value, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_SetInterval(MI_SubscriptionDeliveryOptions *self, const MI_Char *optionName, const MI_Interval *value, MI_Uint32 flags) {
  if (self && self->ft) {
    return self->ft->SetInterval(self, optionName, value, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetString(MI_SubscriptionDeliveryOptions *self, const MI_Char *optionName, const MI_Char **value, MI_Uint32 *index, MI_Uint32 *flags) {
  if (self && self->ft) {
    return self->ft->GetString(self, optionName, value, index, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetNumber(MI_SubscriptionDeliveryOptions *self, const MI_Char *optionName, MI_Uint32 *value, MI_Uint32 *index, MI_Uint32 *flags) {
  if (self && self->ft) {
    return self->ft->GetNumber(self, optionName, value, index, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetDateTime(MI_SubscriptionDeliveryOptions *self, const MI_Char *optionName, MI_Datetime *value, MI_Uint32 *index, MI_Uint32 *flags) {
  if (self && self->ft) {
    return self->ft->GetDateTime(self, optionName, value, index, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetInterval(MI_SubscriptionDeliveryOptions *self, const MI_Char *optionName, MI_Interval *value, MI_Uint32 *index, MI_Uint32 *flags) {
  if (self && self->ft) {
    return self->ft->GetInterval(self, optionName, value, index, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetOptionCount( MI_SubscriptionDeliveryOptions *self, MI_Uint32 *count) {
  if (self && self->ft) {
    return self->ft->GetOptionCount(self, count);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetOptionAt(MI_SubscriptionDeliveryOptions *self, MI_Uint32 index, const MI_Char **optionName, MI_Value *value, MI_Type *type, MI_Uint32 *flags) {
  if (self && self->ft) {
    return self->ft->GetOptionAt(self, index, optionName, value, type, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetOption(MI_SubscriptionDeliveryOptions *self, const MI_Char *optionName, MI_Value *value, MI_Type *type, MI_Uint32 *index, MI_Uint32 *flags) {
  if (self && self->ft) {
    return self->ft->GetOption(self, optionName, value, type, index, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetCredentialsCount(MI_SubscriptionDeliveryOptions *self, MI_Uint32 *count) {
  if (self && self->ft) {
    return self->ft->GetCredentialsCount(self, count);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetCredentialsAt(MI_SubscriptionDeliveryOptions *self, MI_Uint32 index, const MI_Char **optionName, MI_UserCredentials *credentials, MI_Uint32 *flags) {
  if (self && self->ft) {
    return self->ft->GetCredentialsAt(self, index, optionName, credentials, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_SubscriptionDeliveryOptions_GetCredentialsPasswordAt(MI_SubscriptionDeliveryOptions *self, MI_Uint32 index, const MI_Char **optionName, MI_Char *password, MI_Uint32 bufferLength, MI_Uint32 *passwordLength, MI_Uint32 *flags) {
  if (self && self->ft) {
    return self->ft->GetCredentialsPasswordAt(self, index, optionName, password, bufferLength, passwordLength, flags);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

MI_INLINE MI_Result MI_INLINE_CALL MI_SubscriptionDeliveryOptions_Clone(const MI_SubscriptionDeliveryOptions* self, MI_SubscriptionDeliveryOptions* newSubscriptionDeliveryOptions) {
  if (self && self->ft) {
    return self->ft->Clone(self, newSubscriptionDeliveryOptions);
  } else {
    return MI_RESULT_INVALID_PARAMETER;
  }
}

#define MI_SERIALIZER_FLAGS_CLASS_DEEP 1
#define MI_SERIALIZER_FLAGS_INSTANCE_WITH_CLASS 1

MI_INLINE MI_Result MI_Serializer_Close(MI_Serializer *serializer) {
  return mi_clientFT->serializerFT->Close(serializer);
}

MI_INLINE MI_Result MI_Serializer_SerializeClass(MI_Serializer *serializer, MI_Uint32 flags, const MI_Class *classObject,  MI_Uint8 *clientBuffer, MI_Uint32 clientBufferLength,  MI_Uint32 *clientBufferNeeded) {
  return mi_clientFT->serializerFT->SerializeClass(serializer, flags, classObject, clientBuffer, clientBufferLength, clientBufferNeeded);
}

MI_INLINE MI_Result MI_Serializer_SerializeInstance(MI_Serializer *serializer, MI_Uint32 flags, const MI_Instance *instanceObject, MI_Uint8 *clientBuffer, MI_Uint32 clientBufferLength, MI_Uint32 *clientBufferNeeded) {
  return mi_clientFT->serializerFT->SerializeInstance(serializer, flags, instanceObject, clientBuffer, clientBufferLength, clientBufferNeeded);
}

MI_INLINE MI_Result MI_Deserializer_Close(MI_Deserializer *deserializer) {
  const MI_ClientFT_V1 *clientFT = mi_clientFT;
  const MI_DeserializerFT *deserializerFT = clientFT->deserializerFT;
  return deserializerFT->Close(deserializer);
}

MI_INLINE MI_Result MI_Deserializer_DeserializeClass(MI_Deserializer *deserializer, MI_Uint32 flags, MI_Uint8 *serializedBuffer, MI_Uint32 serializedBufferLength, MI_Class *parentClass, const MI_Char *serverName, const MI_Char *namespaceName, MI_Deserializer_ClassObjectNeeded classObjectNeeded, void *classObjectNeededContext, MI_Uint32 *serializedBufferRead, MI_Class **classObject, MI_Instance **cimErrorDetails) {
  return mi_clientFT->deserializerFT->DeserializeClass(deserializer, flags, serializedBuffer, serializedBufferLength, parentClass, serverName, namespaceName, classObjectNeeded, classObjectNeededContext, serializedBufferRead, classObject, cimErrorDetails);
}

MI_INLINE MI_Result MI_Deserializer_Class_GetClassName(MI_Deserializer *deserializer, MI_Uint8 *serializedBuffer, MI_Uint32 serializedBufferLength, MI_Char *className, MI_Uint32 *classNameLength, MI_Instance **cimErrorDetails) {
  return mi_clientFT->deserializerFT->Class_GetClassName(deserializer, serializedBuffer, serializedBufferLength, className, classNameLength, cimErrorDetails);
}

MI_INLINE MI_Result MI_Deserializer_Class_GetParentClassName(MI_Deserializer *deserializer, MI_Uint8 *serializedBuffer, MI_Uint32 serializedBufferLength, MI_Char *parentClassName, MI_Uint32 *parentClassNameLength, MI_Instance **cimErrorDetails) {
  return mi_clientFT->deserializerFT->Class_GetParentClassName(deserializer, serializedBuffer, serializedBufferLength, parentClassName, parentClassNameLength, cimErrorDetails);
}

MI_INLINE MI_Result MI_Deserializer_DeserializeInstance(MI_Deserializer *deserializer, MI_Uint32 flags, MI_Uint8 *serializedBuffer, MI_Uint32 serializedBufferLength, MI_Class **classObjects, MI_Uint32 numberClassObjects, MI_Deserializer_ClassObjectNeeded classObjectNeeded, void *classObjectNeededContext, MI_Uint32 *serializedBufferRead, MI_Instance **instanceObject, MI_Instance **cimErrorDetails) {
  return mi_clientFT->deserializerFT->DeserializeInstance(deserializer, flags, serializedBuffer, serializedBufferLength, classObjects, numberClassObjects, classObjectNeeded, classObjectNeededContext, serializedBufferRead, instanceObject, cimErrorDetails);
}

MI_INLINE MI_Result MI_Deserializer_Instance_GetClassName(MI_Deserializer *deserializer, MI_Uint8 *serializedBuffer, MI_Uint32 serializedBufferLength, MI_Char *className, MI_Uint32 *classNameLength, MI_Instance **cimErrorDetails) {
  return mi_clientFT->deserializerFT->Instance_GetClassName(deserializer, serializedBuffer, serializedBufferLength, className, classNameLength, cimErrorDetails);
}

MI_INLINE MI_ErrorCategory MI_Utilities_MapErrorToMiErrorCategory(MI_Char *errorType, MI_Uint32 error) {
  return mi_clientFT->utilitiesFT->MapErrorToMiErrorCategory(errorType, error);
}

MI_INLINE MI_Result MI_Utilities_CimErrorFromErrorCode(MI_Uint32 error, const MI_Char *errorType, const MI_Char* errorMessage, MI_Instance **cimError) {
  return mi_clientFT->utilitiesFT->CimErrorFromErrorCode(error, errorType, errorMessage, cimError);
}

#define MI_CancelationReason MI_CancellationReason
#define _MI_CancelationReason _MI_CancellationReason
#define MI_PostResult MI_Context_PostResult
#define MI_PostCimError MI_Context_PostCimError
#define MI_PostError MI_Context_PostError
#define MI_PostInstance MI_Context_PostInstance
#define MI_PostIndication MI_Context_PostIndication
#define MI_ConstructInstance MI_Context_ConstructInstance
#define MI_ConstructParameters MI_Context_ConstructParameters
#define MI_NewInstance MI_Context_NewInstance
#define MI_NewDynamicInstance MI_Context_NewDynamicInstance
#define MI_NewParameters MI_Context_NewParameters
#define MI_Canceled MI_Context_Canceled
#define MI_GetLocale MI_Context_GetLocale
#define MI_RegisterCancel MI_Context_RegisterCancel
#define MI_RequestUnload MI_Context_RequestUnload
#define MI_RefuseUnload MI_Context_RefuseUnload
#define MI_GetLocalSession MI_Context_GetLocalSession
#define MI_SetStringOption MI_Context_SetStringOption
#define MI_GetStringOption MI_Context_GetStringOption
#define MI_GetNumberOption MI_Context_GetNumberOption
#define MI_GetCustomOption MI_Context_GetCustomOption
#define MI_GetCustomOptionCount MI_Context_GetCustomOptionCount
#define MI_GetCustomOptionAt MI_Context_GetCustomOptionAt
#define MI_ShouldProcess MI_Context_ShouldProcess
#define MI_ShouldContinue MI_Context_ShouldContinue
#define MI_PromptUser MI_Context_PromptUser
#define MI_WriteError MI_Context_WriteError
#define MI_WriteCimError MI_Context_WriteCimError
#define MI_WriteMessage MI_Context_WriteMessage
#define MI_WriteProgress MI_Context_WriteProgress
#define MI_WriteStreamParameter MI_Context_WriteStreamParameter
#define MI_WriteWarning MI_Context_WriteWarning
#define MI_WriteVerbose MI_Context_WriteVerbose
#define MI_WriteDebug MI_Context_WriteDebug
#define MI_SubscriptionDeliveryOptions__SetExpirationTime MI_SubscriptionDeliveryOptions_SetExpirationTime
#define MI_SubscriptionDeliveryOptions__GetExpirationTime MI_SubscriptionDeliveryOptions_GetExpirationTime

#ifdef __cplusplus
}
#endif

#endif /* __MI_C_API_H */

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP) */
