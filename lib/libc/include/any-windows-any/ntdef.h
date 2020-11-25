/*
 * ntdef.h
 *
 * This file is part of the ReactOS PSDK package.
 *
 * Contributors:
 *   Created by Casper S. Hornstrup <chorns@users.sourceforge.net>
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#ifndef _NTDEF_
#define _NTDEF_

#ifdef _WINNT_
/* FIXME: In version two, warn about including both ntdef.h and winnt.h
 * #warning Including winnt.h and ntdef.h is deprecated and will be removed in a future release.  Please use winternl.h
 */
#endif

#include <_mingw.h>

#if defined(__x86_64) && \
  !(defined(_X86_) || defined(__i386__) || defined(_IA64_))
#if !defined(_AMD64_)
#define _AMD64_
#endif
#endif /* _AMD64_ */

#if defined(__ia64__) && \
  !(defined(_X86_) || defined(__x86_64) || defined(_AMD64_))
#if !defined(_IA64_)
#define _IA64_
#endif
#endif /* _IA64_ */

/* Dependencies */
#include <ctype.h>
#include <basetsd.h>
#include <excpt.h>
#include <sdkddkver.h>
#include <specstrings.h>

/* FIXME: Shouldn't be included! */
#include <stdarg.h>
#include <string.h>

/* Pseudo Modifiers for Input Parameters */

#ifndef IN
#define IN
#endif

#ifndef OUT
#define OUT
#endif

#ifndef OPTIONAL
#define OPTIONAL
#endif

#ifndef NOTHING
#define NOTHING
#endif

#ifndef CRITICAL
#define CRITICAL
#endif

#ifndef FAR
#define FAR
#endif


/* Defines the "size" of an any-size array */
#ifndef ANYSIZE_ARRAY
#define ANYSIZE_ARRAY 1
#endif

/* Constant modifier */
#ifndef CONST
#define CONST const
#endif

/* TRUE/FALSE */
#define FALSE   0
#define TRUE    1

/* NULL/NULL64 */
#ifndef NULL
#ifdef __cplusplus
#ifndef _WIN64
#define NULL    0
#else
#define NULL    0LL
#endif  /* W64 */
#else
#define NULL    ((void *)0)
#endif
#endif /* NULL */
#ifndef NULL64
#ifdef __cplusplus
#define NULL64  0LL
#else
#define NULL64  ((void * POINTER_64)0)
#endif
#endif /* NULL64 */


#undef  UNALIGNED	/* avoid redefinition warnings vs _mingw.h */
#undef  UNALIGNED64
#if defined(_M_MRX000) || defined(_M_ALPHA) || defined(_M_PPC) || defined(_M_IA64) || defined(_M_AMD64) || defined (_M_ARM)
#define ALIGNMENT_MACHINE
#define UNALIGNED __unaligned
#if defined(_WIN64)
#define UNALIGNED64 __unaligned
#else
#define UNALIGNED64
#endif
#else
#undef ALIGNMENT_MACHINE
#define UNALIGNED
#define UNALIGNED64
#endif

#if defined(_WIN64) || defined(_M_ALPHA)
#define MAX_NATURAL_ALIGNMENT sizeof(ULONGLONG)
#define MEMORY_ALLOCATION_ALIGNMENT 16
#else
#define MAX_NATURAL_ALIGNMENT sizeof(ULONG)
#define MEMORY_ALLOCATION_ALIGNMENT 8
#endif

#if defined(_M_MRX000) && !(defined(MIDL_PASS) || defined(RC_INVOKED)) && defined(ENABLE_RESTRICTED)
#define RESTRICTED_POINTER __restrict
#else
#define RESTRICTED_POINTER
#endif


#define ARGUMENT_PRESENT(ArgumentPointer) \
  ((CHAR*)((ULONG_PTR)(ArgumentPointer)) != (CHAR*)NULL)

/* Returns the base address of a structure from a structure member */
#ifndef CONTAINING_RECORD
#define CONTAINING_RECORD(address, type, field) \
  ((type *)(((ULONG_PTR)address) - (ULONG_PTR)(&(((type *)0)->field))))
#endif

/* Returns the byte offset of the specified structure's member */
#ifndef __GNUC__
#define FIELD_OFFSET(Type, Field) ((LONG)(LONG_PTR)&(((Type*) 0)->Field))
#else
#define FIELD_OFFSET(Type, Field) __builtin_offsetof(Type, Field)
#endif

/* Returns the type's alignment */
#if defined(_MSC_VER) && (_MSC_VER >= 1300)
#define TYPE_ALIGNMENT(t) __alignof(t)
#else
#define TYPE_ALIGNMENT(t) FIELD_OFFSET(struct { char x; t test; }, test)
#endif

#if defined (_X86_) || defined (_AMD64_)
#define PROBE_ALIGNMENT(v) TYPE_ALIGNMENT(ULONG)
#elif defined (_IA64_) || defined (_ARM_)
#define PROBE_ALIGNMENT(v) (TYPE_ALIGNMENT(v) > TYPE_ALIGNMENT(ULONG) ? TYPE_ALIGNMENT(v) : TYPE_ALIGNMENT(ULONG))
#endif

/* Calling Conventions */
#if defined(_M_IX86)
#define FASTCALL __fastcall
#else
#define FASTCALL
#endif

#if defined(_ARM_)
#define NTAPI
#else
#define NTAPI __stdcall
#endif


#ifndef NOP_FUNCTION
#if (_MSC_VER >= 1210)
#define NOP_FUNCTION __noop
#else
#define NOP_FUNCTION (void)0
#endif
#endif

/* Import and Export Specifiers */

/* Done the same way as in windef.h for now */
#define DECLSPEC_IMPORT __declspec(dllimport)
#define DECLSPEC_NORETURN __declspec(noreturn)

#ifndef DECLSPEC_ADDRSAFE
#if (_MSC_VER >= 1200) && (defined(_M_ALPHA) || defined(_M_AXP64))
#define DECLSPEC_ADDRSAFE  __declspec(address_safe)
#else
#define DECLSPEC_ADDRSAFE
#endif
#endif /* DECLSPEC_ADDRSAFE */

#if !defined(_NTSYSTEM_)
#define NTSYSAPI     DECLSPEC_IMPORT
#define NTSYSCALLAPI DECLSPEC_IMPORT
#else
#define NTSYSAPI
#if defined(_NTDLLBUILD_)
#define NTSYSCALLAPI
#else
#define NTSYSCALLAPI DECLSPEC_ADDRSAFE
#endif
#endif

/* Inlines */
#ifndef FORCEINLINE
#if !defined(_MSC_VER) || (_MSC_VER >=1200)
#define FORCEINLINE __forceinline
#else
#define FORCEINLINE __inline
#endif
#endif /* FORCEINLINE */

#ifndef DECLSPEC_NOINLINE
#if (_MSC_VER >= 1300)
#define DECLSPEC_NOINLINE  __declspec(noinline)
#elif defined(__GNUC__)
#define DECLSPEC_NOINLINE __attribute__((noinline))
#else
#define DECLSPEC_NOINLINE
#endif
#endif /* DECLSPEC_NOINLINE */

#if !defined(_M_CEE_PURE)
#define NTAPI_INLINE    NTAPI
#else
#define NTAPI_INLINE
#endif

/* Use to specify structure alignment */
#ifndef DECLSPEC_ALIGN
#if defined(_MSC_VER) && (_MSC_VER >= 1300) && !defined(MIDL_PASS)
#define DECLSPEC_ALIGN(x) __declspec(align(x))
#elif defined(__GNUC__)
#define DECLSPEC_ALIGN(x) __attribute__ ((__aligned__ (x)))
#else
#define DECLSPEC_ALIGN(x)
#endif
#endif /* DECLSPEC_ALIGN */

#ifndef SYSTEM_CACHE_ALIGNMENT_SIZE
#if defined(_AMD64_) || defined(_X86_)
#define SYSTEM_CACHE_ALIGNMENT_SIZE 64
#else
#define SYSTEM_CACHE_ALIGNMENT_SIZE 128
#endif
#endif

#ifndef DECLSPEC_CACHEALIGN
#define DECLSPEC_CACHEALIGN DECLSPEC_ALIGN(SYSTEM_CACHE_ALIGNMENT_SIZE)
#endif

#ifndef DECLSPEC_SELECTANY
#if (_MSC_VER >= 1100) || defined(__GNUC__)
#define DECLSPEC_SELECTANY __declspec(selectany)
#else
#define DECLSPEC_SELECTANY
#endif
#endif

/* Use to silence unused variable warnings when it is intentional */
#define UNREFERENCED_PARAMETER(P) {(P) = (P);}
#define UNREFERENCED_LOCAL_VARIABLE(L) {(L) = (L);}
#define DBG_UNREFERENCED_PARAMETER(P) (P)
#define DBG_UNREFERENCED_LOCAL_VARIABLE(L) (L)

/* min/max helper macros */
#ifndef NOMINMAX

#ifndef min
#define min(a,b) (((a) < (b)) ? (a) : (b))
#endif

#ifndef max
#define max(a,b) (((a) > (b)) ? (a) : (b))
#endif

#endif /* NOMINMAX */

/* Tell windef.h that we have defined some basic types */
#define BASETYPES

/* Void Pointers */
typedef void *PVOID;
typedef void * POINTER_64 PVOID64;

/* Handle Type */
#ifdef STRICT
typedef void *HANDLE;
#define DECLARE_HANDLE(n) typedef struct n##__{int i;}*n
#else
typedef PVOID HANDLE;
#define DECLARE_HANDLE(n) typedef HANDLE n
#endif
typedef HANDLE *PHANDLE;

/* Upper-Case Versions of Some Standard C Types */
#ifndef VOID
#define VOID void
typedef char CHAR;
typedef short SHORT;
typedef __LONG32 LONG;
#if !defined(MIDL_PASS) && !defined (__WIDL__)
typedef int INT;
#endif
#endif
typedef double DOUBLE;

/* Unsigned Types */
typedef unsigned char UCHAR, *PUCHAR;
typedef unsigned short USHORT, *PUSHORT;
typedef unsigned __LONG32 ULONG, *PULONG;
typedef CONST UCHAR *PCUCHAR;
typedef CONST USHORT *PCUSHORT;
typedef CONST ULONG *PCULONG;
typedef UCHAR FCHAR;
typedef USHORT FSHORT;
typedef ULONG FLONG;
typedef UCHAR BOOLEAN, *PBOOLEAN;
typedef ULONG LOGICAL;
typedef ULONG *PLOGICAL;

/* Signed Types */
typedef SHORT *PSHORT;
typedef LONG *PLONG;
typedef LONG NTSTATUS;
typedef NTSTATUS *PNTSTATUS;
typedef signed char SCHAR;
typedef SCHAR *PSCHAR;

#ifndef _DEF_WINBOOL_
#define _DEF_WINBOOL_
typedef int WINBOOL;
#pragma push_macro("BOOL")
#undef BOOL
#if !defined(__OBJC__) && !defined(__OBJC_BOOL) && !defined(__objc_INCLUDE_GNU)
typedef int BOOL;
#endif
#define BOOL WINBOOL
typedef BOOL *PBOOL;
typedef BOOL *LPBOOL;
#pragma pop_macro("BOOL")
#endif /* _DEF_WINBOOL_ */

#ifndef _HRESULT_DEFINED
#define _HRESULT_DEFINED
typedef LONG HRESULT;
#endif

/* 64-bit types */
#define _ULONGLONG_
__MINGW_EXTENSION typedef __int64 LONGLONG, *PLONGLONG;
__MINGW_EXTENSION typedef unsigned __int64 ULONGLONG, *PULONGLONG;
#define _DWORDLONG_
typedef ULONGLONG DWORDLONG, *PDWORDLONG;

/* Update Sequence Number */
typedef LONGLONG USN;

/* ANSI (Multi-byte Character) types */
typedef CHAR *PCHAR, *LPCH, *PCH;
typedef CONST CHAR *LPCCH, *PCCH;
typedef CHAR *NPSTR, *LPSTR, *PSTR;
typedef PSTR *PZPSTR;
typedef CONST PSTR *PCZPSTR;
typedef CONST CHAR *LPCSTR, *PCSTR;
typedef PCSTR *PZPCSTR;

/* Pointer to an Asciiz string */
typedef CHAR *PSZ;
typedef CONST char *PCSZ;

/* UNICODE (Wide Character) types */
#ifndef __WCHAR_DEFINED
#define __WCHAR_DEFINED
typedef wchar_t WCHAR;
#endif
typedef WCHAR *PWCHAR, *LPWCH, *PWCH;
typedef CONST WCHAR *LPCWCH, *PCWCH;
typedef WCHAR *NWPSTR, *LPWSTR, *PWSTR;
typedef PWSTR *PZPWSTR;
typedef CONST PWSTR *PCZPWSTR;
typedef WCHAR UNALIGNED *LPUWSTR, *PUWSTR;
typedef CONST WCHAR *LPCWSTR, *PCWSTR;
typedef PCWSTR *PZPCWSTR;
typedef CONST WCHAR UNALIGNED *LPCUWSTR, *PCUWSTR;

/* Cardinal Data Types */
typedef char CCHAR, *PCCHAR;
typedef short CSHORT, *PCSHORT;
typedef ULONG CLONG, *PCLONG;

/* NLS basics (Locale and Language Ids) */
typedef ULONG LCID;
typedef PULONG PLCID;
typedef USHORT LANGID;

/* Used to store a non-float 8 byte aligned structure */
typedef struct _QUAD {
  __C89_NAMELESS union {
    __MINGW_EXTENSION __int64 UseThisFieldToCopy;
    double DoNotUseThisField;
  } DUMMYUNIONNAME;
} QUAD, *PQUAD, UQUAD, *PUQUAD;

#ifndef _LARGE_INTEGER_DEFINED
#define _LARGE_INTEGER_DEFINED
/* Large Integer Unions */
#if defined(MIDL_PASS) || defined (__WIDL__)
typedef struct _LARGE_INTEGER {
#else
typedef union _LARGE_INTEGER {
  __C89_NAMELESS struct {
    ULONG LowPart;
    LONG HighPart;
  } DUMMYSTRUCTNAME;
  struct {
    ULONG LowPart;
    LONG HighPart;
  } u;
#endif /* MIDL_PASS */
  LONGLONG QuadPart;
} LARGE_INTEGER, *PLARGE_INTEGER;

#if defined(MIDL_PASS) || defined (__WIDL__)
typedef struct _ULARGE_INTEGER {
#else
typedef union _ULARGE_INTEGER {
  __C89_NAMELESS struct {
    ULONG LowPart;
    ULONG HighPart;
  } DUMMYSTRUCTNAME;
  struct {
    ULONG LowPart;
    ULONG HighPart;
  } u;
#endif /* MIDL_PASS */
  ULONGLONG QuadPart;
} ULARGE_INTEGER, *PULARGE_INTEGER;

/* Locally Unique Identifier */
typedef struct _LUID {
  ULONG LowPart;
  LONG HighPart;
} LUID, *PLUID;

#endif /* _LARGE_INTEGER_DEFINED */

/* Physical Addresses are always treated as 64-bit wide */
typedef LARGE_INTEGER PHYSICAL_ADDRESS, *PPHYSICAL_ADDRESS;

/* Native API Return Value Macros */
#define NT_SUCCESS(Status)              (((NTSTATUS)(Status)) >= 0)
#define NT_INFORMATION(Status)          ((((ULONG)(Status)) >> 30) == 1)
#define NT_WARNING(Status)              ((((ULONG)(Status)) >> 30) == 2)
#define NT_ERROR(Status)                ((((ULONG)(Status)) >> 30) == 3)

/* String Types */
#ifndef __UNICODE_STRING_DEFINED
#define __UNICODE_STRING_DEFINED
typedef struct _UNICODE_STRING {
  USHORT Length;
  USHORT MaximumLength;
  PWSTR  Buffer;
} UNICODE_STRING, *PUNICODE_STRING;
#endif
typedef const UNICODE_STRING* PCUNICODE_STRING;

#define UNICODE_NULL ((WCHAR)0)

#define UNICODE_STRING_MAX_BYTES ((USHORT) 65534)
#define UNICODE_STRING_MAX_CHARS (32767)

#ifdef _MSC_VER
#define DECLARE_UNICODE_STRING_SIZE(_var, _size) \
  WCHAR _var ## _buffer[_size]; \
  __pragma(warning(push)) __pragma(warning(disable:4221)) __pragma(warning(disable:4204)) \
  UNICODE_STRING _var = { 0, (_size) * sizeof(WCHAR) , _var ## _buffer } \
  __pragma(warning(pop))

#define DECLARE_CONST_UNICODE_STRING(_var, _string) \
  const WCHAR _var##_buffer[] = _string; \
  __pragma(warning(push)) __pragma(warning(disable:4221)) __pragma(warning(disable:4204)) \
  const UNICODE_STRING _var = { sizeof(_string) - sizeof(WCHAR), sizeof(_string), (PWCH)_var##_buffer } \
  __pragma(warning(pop))
#else
#define DECLARE_UNICODE_STRING_SIZE(_var, _size) \
  WCHAR _var ## _buffer[_size]; \
  UNICODE_STRING _var = { 0, (_size) * sizeof(WCHAR) , _var ## _buffer }

#define DECLARE_CONST_UNICODE_STRING(_var, _string) \
  const WCHAR _var##_buffer[] = _string; \
  const UNICODE_STRING _var = { sizeof(_string) - sizeof(WCHAR), sizeof(_string), (PWCH)_var##_buffer }
#endif

typedef struct _CSTRING {
  USHORT Length;
  USHORT MaximumLength;
  CONST CHAR *Buffer;
} CSTRING, *PCSTRING;
#define ANSI_NULL ((CHAR)0)

#ifndef __STRING_DEFINED
#define __STRING_DEFINED
typedef struct _STRING {
  USHORT Length;
  USHORT MaximumLength;
  PCHAR  Buffer;
} STRING, *PSTRING;
#endif

typedef STRING ANSI_STRING;
typedef PSTRING PANSI_STRING;
typedef STRING OEM_STRING;
typedef PSTRING POEM_STRING;
typedef CONST STRING* PCOEM_STRING;
typedef STRING CANSI_STRING;
typedef PSTRING PCANSI_STRING;
typedef STRING UTF8_STRING;
typedef PSTRING PUTF8_STRING;

typedef struct _STRING32 {
  USHORT Length;
  USHORT MaximumLength;
  ULONG  Buffer;
} STRING32, *PSTRING32, 
  UNICODE_STRING32, *PUNICODE_STRING32, 
  ANSI_STRING32, *PANSI_STRING32;

typedef struct _STRING64 {
  USHORT Length;
  USHORT MaximumLength;
  ULONGLONG Buffer;
} STRING64, *PSTRING64,
  UNICODE_STRING64, *PUNICODE_STRING64, 
  ANSI_STRING64, *PANSI_STRING64;

/* LangID and NLS */
#define MAKELANGID(p, s)       ((((USHORT)(s)) << 10) | (USHORT)(p))
#define PRIMARYLANGID(lgid)    ((USHORT)(lgid) & 0x3ff)
#define SUBLANGID(lgid)        ((USHORT)(lgid) >> 10)

#define NLS_VALID_LOCALE_MASK  0x000fffff

#define MAKELCID(lgid, srtid)  ((ULONG)((((ULONG)((USHORT)(srtid))) << 16) |  \
                                         ((ULONG)((USHORT)(lgid)))))
#define MAKESORTLCID(lgid, srtid, ver)                                        \
                               ((ULONG)((MAKELCID(lgid, srtid)) |             \
                                    (((ULONG)((USHORT)(ver))) << 20)))
#define LANGIDFROMLCID(lcid)   ((USHORT)(lcid))
#define SORTIDFROMLCID(lcid)   ((USHORT)((((ULONG)(lcid)) >> 16) & 0xf))
#define SORTVERSIONFROMLCID(lcid)  ((USHORT)((((ULONG)(lcid)) >> 20) & 0xf))


/* Object Attributes */
#ifndef __OBJECT_ATTRIBUTES_DEFINED
#define __OBJECT_ATTRIBUTES_DEFINED
typedef struct _OBJECT_ATTRIBUTES {
  ULONG Length;
  HANDLE RootDirectory;
  PUNICODE_STRING ObjectName;
  ULONG Attributes;
  PVOID SecurityDescriptor;
  PVOID SecurityQualityOfService;
} OBJECT_ATTRIBUTES, *POBJECT_ATTRIBUTES;
#endif
typedef CONST OBJECT_ATTRIBUTES *PCOBJECT_ATTRIBUTES;

typedef struct _OBJECT_ATTRIBUTES64 {
  ULONG Length;
  ULONG64 RootDirectory;
  ULONG64 ObjectName;
  ULONG Attributes;
  ULONG64 SecurityDescriptor;
  ULONG64 SecurityQualityOfService;
} OBJECT_ATTRIBUTES64, *POBJECT_ATTRIBUTES64;
typedef CONST OBJECT_ATTRIBUTES64 *PCOBJECT_ATTRIBUTES64;

typedef struct _OBJECT_ATTRIBUTES32 {
  ULONG Length;
  ULONG RootDirectory;
  ULONG ObjectName;
  ULONG Attributes;
  ULONG SecurityDescriptor;
  ULONG SecurityQualityOfService;
} OBJECT_ATTRIBUTES32, *POBJECT_ATTRIBUTES32;
typedef CONST OBJECT_ATTRIBUTES32 *PCOBJECT_ATTRIBUTES32;

/* Values for the Attributes member */
#define OBJ_INHERIT             0x00000002
#define OBJ_PERMANENT           0x00000010
#define OBJ_EXCLUSIVE           0x00000020
#define OBJ_CASE_INSENSITIVE    0x00000040
#define OBJ_OPENIF              0x00000080
#define OBJ_OPENLINK            0x00000100
#define OBJ_KERNEL_HANDLE       0x00000200
#define OBJ_FORCE_ACCESS_CHECK  0x00000400
#define OBJ_IGNORE_IMPERSONATED_DEVICEMAP 0x00000800
#define OBJ_DONT_REPARSE        0x00001000
#define OBJ_VALID_ATTRIBUTES    0x00001FF2

/* Helper Macro */
#define InitializeObjectAttributes(p,n,a,r,s) { \
  (p)->Length = sizeof(OBJECT_ATTRIBUTES); \
  (p)->RootDirectory = (r); \
  (p)->Attributes = (a); \
  (p)->ObjectName = (n); \
  (p)->SecurityDescriptor = (s); \
  (p)->SecurityQualityOfService = NULL; \
}

#define RTL_CONSTANT_OBJECT_ATTRIBUTES(n, a) { sizeof(OBJECT_ATTRIBUTES), NULL, RTL_CONST_CAST(PUNICODE_STRING)(n), a, NULL, NULL }
#define RTL_INIT_OBJECT_ATTRIBUTES(n, a) RTL_CONSTANT_OBJECT_ATTRIBUTES(n, a)

/* Product Types */
typedef enum _NT_PRODUCT_TYPE {
  NtProductWinNt = 1,
  NtProductLanManNt,
  NtProductServer
} NT_PRODUCT_TYPE, *PNT_PRODUCT_TYPE;

typedef enum _EVENT_TYPE {
  NotificationEvent,
  SynchronizationEvent
} EVENT_TYPE;

typedef enum _TIMER_TYPE {
  NotificationTimer,
  SynchronizationTimer
} TIMER_TYPE;

typedef enum _WAIT_TYPE {
  WaitAll,
  WaitAny
} WAIT_TYPE;

#ifndef _LIST_ENTRY_DEFINED
#define _LIST_ENTRY_DEFINED

/* Doubly Linked Lists */
typedef struct _LIST_ENTRY {
  struct _LIST_ENTRY *Flink;
  struct _LIST_ENTRY *Blink;
} LIST_ENTRY, *PLIST_ENTRY, *RESTRICTED_POINTER PRLIST_ENTRY;

typedef struct LIST_ENTRY32 {
  ULONG Flink;
  ULONG Blink;
} LIST_ENTRY32, *PLIST_ENTRY32;

typedef struct LIST_ENTRY64 {
  ULONGLONG Flink;
  ULONGLONG Blink;
} LIST_ENTRY64, *PLIST_ENTRY64;

/* Singly Linked Lists */
typedef struct _SINGLE_LIST_ENTRY32 {
  ULONG Next;
} SINGLE_LIST_ENTRY32, *PSINGLE_LIST_ENTRY32;

typedef struct _SINGLE_LIST_ENTRY {
  struct _SINGLE_LIST_ENTRY *Next;
} SINGLE_LIST_ENTRY, *PSINGLE_LIST_ENTRY;

#endif /* _LIST_ENTRY_DEFINED */

typedef struct _RTL_BALANCED_NODE {
  __C89_NAMELESS union {
    struct _RTL_BALANCED_NODE *Children[2];
    __C89_NAMELESS struct {
      struct _RTL_BALANCED_NODE *Left;
      struct _RTL_BALANCED_NODE *Right;
    };
  };

#define RTL_BALANCED_NODE_RESERVED_PARENT_MASK 3

  __C89_NAMELESS union {
    UCHAR Red : 1;
    UCHAR Balance : 2;
    ULONG_PTR ParentValue;
  };
} RTL_BALANCED_NODE, *PRTL_BALANCED_NODE;

#define RTL_BALANCED_NODE_GET_PARENT_POINTER(Node) ((PRTL_BALANCED_NODE)((Node)->ParentValue & ~RTL_BALANCED_NODE_RESERVED_PARENT_MASK))

#define ALL_PROCESSOR_GROUPS 0xffff

#ifndef ___PROCESSOR_NUMBER_DEFINED
#define ___PROCESSOR_NUMBER_DEFINED
typedef struct _PROCESSOR_NUMBER {
  USHORT Group;
  UCHAR Number;
  UCHAR Reserved;
} PROCESSOR_NUMBER, *PPROCESSOR_NUMBER;
#endif /* !___PROCESSOR_NUMBER_DEFINED */

struct _CONTEXT;
struct _EXCEPTION_RECORD;

#ifndef __PEXCEPTION_ROUTINE_DEFINED
#define __PEXCEPTION_ROUTINE_DEFINED
typedef EXCEPTION_DISPOSITION
(NTAPI *PEXCEPTION_ROUTINE)(
  struct _EXCEPTION_RECORD *ExceptionRecord,
  PVOID EstablisherFrame,
  struct _CONTEXT *ContextRecord,
  PVOID DispatcherContext);
#endif /* __PEXCEPTION_ROUTINE_DEFINED */

#ifndef ___GROUP_AFFINITY_DEFINED
#define ___GROUP_AFFINITY_DEFINED
typedef struct _GROUP_AFFINITY {
  KAFFINITY Mask;
  USHORT Group;
  USHORT Reserved[3];
} GROUP_AFFINITY, *PGROUP_AFFINITY;
#endif /* !___GROUP_AFFINITY_DEFINED */

#ifndef _DEFINED__WNF_STATE_NAME
#define _DEFINED__WNF_STATE_NAME
typedef struct _WNF_STATE_NAME {
  ULONG Data[2];
} WNF_STATE_NAME, *PWNF_STATE_NAME;
typedef const WNF_STATE_NAME *PCWNF_STATE_NAME;
#endif

/* Helper Macros */
#define RTL_FIELD_TYPE(type, field)    (((type*)0)->field)
#define RTL_BITS_OF(sizeOfArg)         (sizeof(sizeOfArg) * 8)
#define RTL_BITS_OF_FIELD(type, field) (RTL_BITS_OF(RTL_FIELD_TYPE(type, field)))

#define RTL_CONSTANT_STRING(s) { sizeof(s)-sizeof((s)[0]), sizeof(s), s }

#define RTL_FIELD_SIZE(type, field) (sizeof(((type *)0)->field))

#define RTL_SIZEOF_THROUGH_FIELD(type, field) \
    (FIELD_OFFSET(type, field) + RTL_FIELD_SIZE(type, field))

#define RTL_CONTAINS_FIELD(Struct, Size, Field) \
    ( (((PCHAR)(&(Struct)->Field)) + sizeof((Struct)->Field)) <= (((PCHAR)(Struct))+(Size)) )

#define RTL_NUMBER_OF_V1(A) (sizeof(A)/sizeof((A)[0]))
#define RTL_NUMBER_OF_V2(A) RTL_NUMBER_OF_V1(A)
#ifdef ENABLE_RTL_NUMBER_OF_V2
#define RTL_NUMBER_OF(A) RTL_NUMBER_OF_V2(A)
#else
#define RTL_NUMBER_OF(A) RTL_NUMBER_OF_V1(A)
#endif
#define ARRAYSIZE(A)    RTL_NUMBER_OF_V2(A)
#define _ARRAYSIZE(A)   RTL_NUMBER_OF_V1(A)

#define RTL_NUMBER_OF_FIELD(type, field) (RTL_NUMBER_OF(RTL_FIELD_TYPE(type, field)))

/* Type Limits */
#define MINCHAR   0x80
#define MAXCHAR   0x7f
#define MINSHORT  0x8000
#define MAXSHORT  0x7fff
#define MINLONG   0x80000000
#define MAXLONG   0x7fffffff
#define MAXUCHAR  0xff
#define MAXUSHORT 0xffff
#define MAXULONG  0xffffffff
#define MAXLONGLONG (0x7fffffffffffffffll)

/* Multiplication and Shift Operations */
#define Int32x32To64(a, b) (((LONGLONG) ((LONG) (a))) * ((LONGLONG) ((LONG) (b))))
#define UInt32x32To64(a, b) (((ULONGLONG) ((unsigned int) (a))) *((ULONGLONG) ((unsigned int) (b))))
#define Int64ShllMod32(a, b) (((ULONGLONG) (a)) << (b))
#define Int64ShraMod32(a, b) (((LONGLONG) (a)) >> (b))
#define Int64ShrlMod32(a, b) (((ULONGLONG) (a)) >> (b))

/* C_ASSERT Definition */
#define C_ASSERT(expr) extern char (*c_assert(void)) [(expr) ? 1 : -1]

#define VER_WORKSTATION_NT                  0x40000000
#define VER_SERVER_NT                       0x80000000
#define VER_SUITE_SMALLBUSINESS             0x00000001
#define VER_SUITE_ENTERPRISE                0x00000002
#define VER_SUITE_BACKOFFICE                0x00000004
#define VER_SUITE_COMMUNICATIONS            0x00000008
#define VER_SUITE_TERMINAL                  0x00000010
#define VER_SUITE_SMALLBUSINESS_RESTRICTED  0x00000020
#define VER_SUITE_EMBEDDEDNT                0x00000040
#define VER_SUITE_DATACENTER                0x00000080
#define VER_SUITE_SINGLEUSERTS              0x00000100
#define VER_SUITE_PERSONAL                  0x00000200
#define VER_SUITE_BLADE                     0x00000400
#define VER_SUITE_EMBEDDED_RESTRICTED       0x00000800
#define VER_SUITE_SECURITY_APPLIANCE        0x00001000
#define VER_SUITE_STORAGE_SERVER            0x00002000
#define VER_SUITE_COMPUTE_SERVER            0x00004000
#define VER_SUITE_WH_SERVER                 0x00008000
#define VER_SUITE_MULTIUSERTS               0x00020000

/*  Primary language IDs. */
#define LANG_NEUTRAL                              0x00
#define LANG_INVARIANT                            0x7f

#define LANG_AFRIKAANS                            0x36
#define LANG_ALBANIAN                             0x1c
#define LANG_ALSATIAN                             0x84
#define LANG_AMHARIC                              0x5e
#define LANG_ARABIC                               0x01
#define LANG_ARMENIAN                             0x2b
#define LANG_ASSAMESE                             0x4d
#define LANG_AZERI                                0x2c
#define LANG_BASHKIR                              0x6d
#define LANG_BASQUE                               0x2d
#define LANG_BELARUSIAN                           0x23
#define LANG_BENGALI                              0x45
#define LANG_BRETON                               0x7e
#define LANG_BOSNIAN                              0x1a
#define LANG_BOSNIAN_NEUTRAL                    0x781a
#define LANG_BULGARIAN                            0x02
#define LANG_CATALAN                              0x03
#define LANG_CHINESE                              0x04
#define LANG_CHINESE_SIMPLIFIED                   0x04
#define LANG_CHINESE_TRADITIONAL                0x7c04
#define LANG_CORSICAN                             0x83
#define LANG_CROATIAN                             0x1a
#define LANG_CZECH                                0x05
#define LANG_DANISH                               0x06
#define LANG_DARI                                 0x8c
#define LANG_DIVEHI                               0x65
#define LANG_DUTCH                                0x13
#define LANG_ENGLISH                              0x09
#define LANG_ESTONIAN                             0x25
#define LANG_FAEROESE                             0x38
#define LANG_FARSI                                0x29
#define LANG_FILIPINO                             0x64
#define LANG_FINNISH                              0x0b
#define LANG_FRENCH                               0x0c
#define LANG_FRISIAN                              0x62
#define LANG_GALICIAN                             0x56
#define LANG_GEORGIAN                             0x37
#define LANG_GERMAN                               0x07
#define LANG_GREEK                                0x08
#define LANG_GREENLANDIC                          0x6f
#define LANG_GUJARATI                             0x47
#define LANG_HAUSA                                0x68
#define LANG_HEBREW                               0x0d
#define LANG_HINDI                                0x39
#define LANG_HUNGARIAN                            0x0e
#define LANG_ICELANDIC                            0x0f
#define LANG_IGBO                                 0x70
#define LANG_INDONESIAN                           0x21
#define LANG_INUKTITUT                            0x5d
#define LANG_IRISH                                0x3c
#define LANG_ITALIAN                              0x10
#define LANG_JAPANESE                             0x11
#define LANG_KANNADA                              0x4b
#define LANG_KASHMIRI                             0x60
#define LANG_KAZAK                                0x3f
#define LANG_KHMER                                0x53
#define LANG_KICHE                                0x86
#define LANG_KINYARWANDA                          0x87
#define LANG_KONKANI                              0x57
#define LANG_KOREAN                               0x12
#define LANG_KYRGYZ                               0x40
#define LANG_LAO                                  0x54
#define LANG_LATVIAN                              0x26
#define LANG_LITHUANIAN                           0x27
#define LANG_LOWER_SORBIAN                        0x2e
#define LANG_LUXEMBOURGISH                        0x6e
#define LANG_MACEDONIAN                           0x2f
#define LANG_MALAY                                0x3e
#define LANG_MALAYALAM                            0x4c
#define LANG_MALTESE                              0x3a
#define LANG_MANIPURI                             0x58
#define LANG_MAORI                                0x81
#define LANG_MAPUDUNGUN                           0x7a
#define LANG_MARATHI                              0x4e
#define LANG_MOHAWK                               0x7c
#define LANG_MONGOLIAN                            0x50
#define LANG_NEPALI                               0x61
#define LANG_NORWEGIAN                            0x14
#define LANG_OCCITAN                              0x82
#define LANG_ORIYA                                0x48
#define LANG_PASHTO                               0x63
#define LANG_PERSIAN                              0x29
#define LANG_POLISH                               0x15
#define LANG_PORTUGUESE                           0x16
#define LANG_PUNJABI                              0x46
#define LANG_QUECHUA                              0x6b
#define LANG_ROMANIAN                             0x18
#define LANG_ROMANSH                              0x17
#define LANG_RUSSIAN                              0x19
#define LANG_SAMI                                 0x3b
#define LANG_SANSKRIT                             0x4f
#define LANG_SERBIAN                              0x1a
#define LANG_SERBIAN_NEUTRAL                    0x7c1a
#define LANG_SINDHI                               0x59
#define LANG_SINHALESE                            0x5b
#define LANG_SLOVAK                               0x1b
#define LANG_SLOVENIAN                            0x24
#define LANG_SOTHO                                0x6c
#define LANG_SPANISH                              0x0a
#define LANG_SWAHILI                              0x41
#define LANG_SWEDISH                              0x1d
#define LANG_SYRIAC                               0x5a
#define LANG_TAJIK                                0x28
#define LANG_TAMAZIGHT                            0x5f
#define LANG_TAMIL                                0x49
#define LANG_TATAR                                0x44
#define LANG_TELUGU                               0x4a
#define LANG_THAI                                 0x1e
#define LANG_TIBETAN                              0x51
#define LANG_TIGRIGNA                             0x73
#define LANG_TSWANA                               0x32
#define LANG_TURKISH                              0x1f
#define LANG_TURKMEN                              0x42
#define LANG_UIGHUR                               0x80
#define LANG_UKRAINIAN                            0x22
#define LANG_UPPER_SORBIAN                        0x2e
#define LANG_URDU                                 0x20
#define LANG_UZBEK                                0x43
#define LANG_VIETNAMESE                           0x2a
#define LANG_WELSH                                0x52
#define LANG_WOLOF                                0x88
#define LANG_XHOSA                                0x34
#define LANG_YAKUT                                0x85
#define LANG_YI                                   0x78
#define LANG_YORUBA                               0x6a
#define LANG_ZULU                                 0x35

#ifndef NT_INCLUDED

#define FILE_ATTRIBUTE_VALID_FLAGS 0x00007fb7
#define FILE_SHARE_VALID_FLAGS (FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE)

#define FILE_SUPERSEDE                    0x00000000
#define FILE_OPEN                         0x00000001
#define FILE_CREATE                       0x00000002
#define FILE_OPEN_IF                      0x00000003
#define FILE_OVERWRITE                    0x00000004
#define FILE_OVERWRITE_IF                 0x00000005
#define FILE_MAXIMUM_DISPOSITION          0x00000005

#define FILE_DIRECTORY_FILE               0x00000001
#define FILE_WRITE_THROUGH                0x00000002
#define FILE_SEQUENTIAL_ONLY              0x00000004
#define FILE_NO_INTERMEDIATE_BUFFERING    0x00000008
#define FILE_SYNCHRONOUS_IO_ALERT         0x00000010
#define FILE_SYNCHRONOUS_IO_NONALERT      0x00000020
#define FILE_NON_DIRECTORY_FILE           0x00000040
#define FILE_CREATE_TREE_CONNECTION       0x00000080
#define FILE_COMPLETE_IF_OPLOCKED         0x00000100
#define FILE_NO_EA_KNOWLEDGE              0x00000200
#define FILE_OPEN_REMOTE_INSTANCE         0x00000400
#define FILE_RANDOM_ACCESS                0x00000800
#define FILE_DELETE_ON_CLOSE              0x00001000
#define FILE_OPEN_BY_FILE_ID              0x00002000
#define FILE_OPEN_FOR_BACKUP_INTENT       0x00004000
#define FILE_NO_COMPRESSION               0x00008000
#if (NTDDI_VERSION >= NTDDI_WIN7)
#define FILE_OPEN_REQUIRING_OPLOCK        0x00010000
#define FILE_DISALLOW_EXCLUSIVE           0x00020000
#endif /* (NTDDI_VERSION >= NTDDI_WIN7) */
#define FILE_RESERVE_OPFILTER             0x00100000
#define FILE_OPEN_REPARSE_POINT           0x00200000
#define FILE_OPEN_NO_RECALL               0x00400000
#define FILE_OPEN_FOR_FREE_SPACE_QUERY    0x00800000

typedef struct _REPARSE_DATA_BUFFER
{
  ULONG  ReparseTag;
  USHORT ReparseDataLength;
  USHORT Reserved;
  union
  {
    struct
    {
      USHORT SubstituteNameOffset;
      USHORT SubstituteNameLength;
      USHORT PrintNameOffset;
      USHORT PrintNameLength;
      ULONG  Flags;
      WCHAR  PathBuffer[1];
    } SymbolicLinkReparseBuffer;
    struct
    {
      USHORT SubstituteNameOffset;
      USHORT SubstituteNameLength;
      USHORT PrintNameOffset;
      USHORT PrintNameLength;
      WCHAR  PathBuffer[1];
    } MountPointReparseBuffer;
    struct
    {
      UCHAR  DataBuffer[1];
    } GenericReparseBuffer;
  };
} REPARSE_DATA_BUFFER, *PREPARSE_DATA_BUFFER;

#define REPARSE_DATA_BUFFER_HEADER_SIZE      FIELD_OFFSET(REPARSE_DATA_BUFFER, GenericReparseBuffer)

#endif /* !NT_DEFINED */

#endif /* _NTDEF_ */

