/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _WINNT_
#define _WINNT_

#include <_mingw_unicode.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <_mingw.h>
#include <ctype.h>
#include <excpt.h>
#include <winapifamily.h>
#include <apiset.h>

#define ANYSIZE_ARRAY 1

#include <specstrings.h>

#ifndef __WIDL__
#define __INTRINSIC_GROUP_WINNT /* only define the intrinsics in this file */
#include <psdk_inc/intrin-impl.h>
#endif

#if defined(__x86_64) && \
  !(defined(_X86_) || defined(__i386__) || defined(_IA64_) || defined (__arm__) || defined(__aarch64__))
#if !defined(_AMD64_)
#define _AMD64_
#endif
#endif /* _AMD64_ */

#if defined(__arm__) && \
  !(defined(_X86_) || defined(__x86_64) || defined(_AMD64_) || defined (__ia64__) || defined(__aarch64__))
#if !defined(_ARM_)
#define _ARM_
#endif
#endif /* _ARM_ */

#if defined(__aarch64__) && \
  !(defined(_X86_) || defined(__x86_64) || defined(_AMD64_) || defined (__ia64__) || defined(__arm__))
#if !defined(_ARM64_)
#define _ARM64_
#endif
#endif /* _ARM64_ */

#if defined(__ia64__) && \
  !(defined(_X86_) || defined(__x86_64) || defined(_AMD64_) || defined (__arm__) || defined(__aarch64__))
#if !defined(_IA64_)
#define _IA64_
#endif
#endif /* _IA64_ */

#include <sdkddkver.h>

#ifndef DUMMYUNIONNAME
#if defined (NONAMELESSUNION)
#define DUMMYUNIONNAME u
#define DUMMYUNIONNAME2 u2
#define DUMMYUNIONNAME3 u3
#define DUMMYUNIONNAME4 u4
#define DUMMYUNIONNAME5 u5
#define DUMMYUNIONNAME6 u6
#define DUMMYUNIONNAME7 u7
#define DUMMYUNIONNAME8 u8
#define DUMMYUNIONNAME9 u9
#else
#define DUMMYUNIONNAME
#define DUMMYUNIONNAME2
#define DUMMYUNIONNAME3
#define DUMMYUNIONNAME4
#define DUMMYUNIONNAME5
#define DUMMYUNIONNAME6
#define DUMMYUNIONNAME7
#define DUMMYUNIONNAME8
#define DUMMYUNIONNAME9
#endif
#endif

#ifndef DUMMYSTRUCTNAME
#if defined (NONAMELESSUNION)
#define DUMMYSTRUCTNAME s
#define DUMMYSTRUCTNAME2 s2
#define DUMMYSTRUCTNAME3 s3
#define DUMMYSTRUCTNAME4 s4
#define DUMMYSTRUCTNAME5 s5
#else
#define DUMMYSTRUCTNAME
#define DUMMYSTRUCTNAME2
#define DUMMYSTRUCTNAME3
#define DUMMYSTRUCTNAME4
#define DUMMYSTRUCTNAME5
#endif
#endif

#define RESTRICTED_POINTER

#undef  UNALIGNED	/* avoid redefinition warnings vs _mingw.h */
#undef  UNALIGNED64
#if defined (__ia64__) || defined (__x86_64__) || defined (__arm__) || defined(__aarch64__)
#define ALIGNMENT_MACHINE
#define UNALIGNED __unaligned
#if defined (_WIN64)
#define UNALIGNED64 __unaligned
#else
#define UNALIGNED64
#endif
#else
#undef ALIGNMENT_MACHINE
#define UNALIGNED
#define UNALIGNED64
#endif

#ifdef _WIN64
#define MAX_NATURAL_ALIGNMENT sizeof(ULONGLONG)
#define MEMORY_ALLOCATION_ALIGNMENT 16
#else
#define MAX_NATURAL_ALIGNMENT sizeof(DWORD)
#define MEMORY_ALLOCATION_ALIGNMENT 8
#endif

#ifdef __cplusplus
#define TYPE_ALIGNMENT(t) __alignof__ (t)
#else
#define TYPE_ALIGNMENT(t) FIELD_OFFSET(struct { char x; t test; }, test)
#endif

#if defined (__x86_64__) || defined (__i386__)
#define PROBE_ALIGNMENT(_s) TYPE_ALIGNMENT (DWORD)
#elif defined (__ia64__) || defined (__arm__) || defined(__aarch64__)
#define PROBE_ALIGNMENT(_s) (TYPE_ALIGNMENT (_s) > TYPE_ALIGNMENT (DWORD) ? TYPE_ALIGNMENT (_s) : TYPE_ALIGNMENT (DWORD))
#elif !defined (RC_INVOKED) && !defined (__WIDL__)
#error No supported target architecture.
#endif

#ifdef _WIN64
#define PROBE_ALIGNMENT32(_s) TYPE_ALIGNMENT (DWORD)
#endif

#if defined(_MSC_VER)
# define C_ASSERT(e) typedef char __C_ASSERT__[(e)?1:-1]
#else
# define C_ASSERT(e) extern void __C_ASSERT__(int [(e)?1:-1])
#endif

#include <basetsd.h>

#ifndef DECLSPEC_IMPORT
#if (defined (__i386__) || defined (__ia64__) || defined (__x86_64__) || defined (__arm__) || defined(__aarch64__)) && !defined (__WIDL__)
#define DECLSPEC_IMPORT __declspec (dllimport)
#else
#define DECLSPEC_IMPORT
#endif
#endif

#ifndef DECLSPEC_NORETURN
#ifndef __WIDL__
#define DECLSPEC_NORETURN __declspec (noreturn)
#else
#define DECLSPEC_NORETURN
#endif
#endif

#ifndef DECLSPEC_NOTHROW
#ifndef __WIDL__
#define DECLSPEC_NOTHROW __declspec (nothrow)
#else
#define DECLSPEC_NOTHROW
#endif
#endif

#ifndef DECLSPEC_ALIGN
#ifndef __WIDL__
#if defined(_MSC_VER) && (_MSC_VER >= 1300) && !defined(MIDL_PASS)
#define DECLSPEC_ALIGN(x) __declspec(align(x))
#elif defined(__GNUC__)
#define DECLSPEC_ALIGN(x) __attribute__ ((__aligned__ (x)))
#else
#define DECLSPEC_ALIGN(x) /*__declspec (align (x))*/
#endif
#else
#define DECLSPEC_ALIGN(x)
#endif
#endif /* DECLSPEC_ALIGN */

#ifndef SYSTEM_CACHE_ALIGNMENT_SIZE
#if defined(__x86_64__) || defined(__i386__)
#define SYSTEM_CACHE_ALIGNMENT_SIZE 64
#else
#define SYSTEM_CACHE_ALIGNMENT_SIZE 128
#endif
#endif

#ifndef DECLSPEC_CACHEALIGN
#define DECLSPEC_CACHEALIGN DECLSPEC_ALIGN(SYSTEM_CACHE_ALIGNMENT_SIZE)
#endif

#ifndef DECLSPEC_UUID
#define DECLSPEC_UUID(x)
#endif

#ifndef DECLSPEC_NOVTABLE
#define DECLSPEC_NOVTABLE
#endif

#ifndef DECLSPEC_SELECTANY
#define DECLSPEC_SELECTANY __declspec(selectany)
#endif

#ifndef NOP_FUNCTION
#if (_MSC_VER >= 1210)
#define NOP_FUNCTION __noop
#else
#define NOP_FUNCTION (void)0
#endif
#endif

#ifndef DECLSPEC_ADDRSAFE
#define DECLSPEC_ADDRSAFE
#endif

#ifndef DECLSPEC_NOINLINE
#if (_MSC_VER >= 1300)
#define DECLSPEC_NOINLINE  __declspec(noinline)
#elif defined(__GNUC__)
#define DECLSPEC_NOINLINE __attribute__((noinline))
#else
#define DECLSPEC_NOINLINE
#endif
#endif /* DECLSPEC_NOINLINE */

#ifndef FORCEINLINE
#if !defined(_MSC_VER) || (_MSC_VER >=1200)
#define FORCEINLINE __forceinline
#else
#define FORCEINLINE __inline
#endif
#endif /* FORCEINLINE */

#ifndef DECLSPEC_DEPRECATED
#if !defined (__WIDL__)
#define DECLSPEC_DEPRECATED __declspec(deprecated)
#define DEPRECATE_SUPPORTED
#else
#define DECLSPEC_DEPRECATED
#undef DEPRECATE_SUPPORTED
#endif
#endif

#define DECLSPEC_DEPRECATED_DDK
#define PRAGMA_DEPRECATED_DDK 0

  typedef void *PVOID;
  typedef void *PVOID64;

#ifndef FASTCALL
#if defined (__i386__) && !defined (__WIDL__)
#define FASTCALL __fastcall
#else
#define FASTCALL
#endif
#endif /* FASTCALL */

#if defined(_ARM_) || defined(_ARM64_)
#define NTAPI
#else
#define NTAPI __stdcall
#endif
#define NTAPI_INLINE NTAPI

#if !defined(_NTSYSTEM_)
#define NTSYSAPI DECLSPEC_IMPORT
#define NTSYSCALLAPI DECLSPEC_IMPORT
#else
#define NTSYSAPI
#define NTSYSCALLAPI DECLSPEC_ADDRSAFE
#endif

#ifndef VOID
#define VOID void
  typedef char CHAR;
  typedef short SHORT;
  typedef __LONG32 LONG;
#if !defined (__WIDL__)
  typedef int INT;
#endif
#endif

#ifndef __WCHAR_DEFINED
#define __WCHAR_DEFINED
  typedef wchar_t WCHAR;
#endif
  typedef WCHAR *PWCHAR,*LPWCH,*PWCH;
  typedef CONST WCHAR *LPCWCH,*PCWCH;
  typedef WCHAR *NWPSTR,*LPWSTR,*PWSTR;
  typedef PWSTR *PZPWSTR;
  typedef CONST PWSTR *PCZPWSTR;
  typedef WCHAR UNALIGNED *LPUWSTR,*PUWSTR;
  typedef CONST WCHAR *LPCWSTR,*PCWSTR;
  typedef PCWSTR *PZPCWSTR;
  typedef CONST WCHAR UNALIGNED *LPCUWSTR,*PCUWSTR;
  typedef WCHAR *PZZWSTR;
  typedef CONST WCHAR *PCZZWSTR;
  typedef WCHAR UNALIGNED *PUZZWSTR;
  typedef CONST WCHAR UNALIGNED *PCUZZWSTR;
  typedef WCHAR *PNZWCH;
  typedef CONST WCHAR *PCNZWCH;
  typedef WCHAR UNALIGNED *PUNZWCH;
  typedef CONST WCHAR UNALIGNED *PCUNZWCH;

#if _WIN32_WINNT >= 0x0600 || (defined (__cplusplus) && defined (WINDOWS_ENABLE_CPLUSPLUS))
  typedef CONST WCHAR *LPCWCHAR,*PCWCHAR;
  typedef CONST WCHAR UNALIGNED *LPCUWCHAR,*PCUWCHAR;
  typedef unsigned long UCSCHAR;

#define UCSCHAR_INVALID_CHARACTER (0xffffffff)
#define MIN_UCSCHAR (0)
#define MAX_UCSCHAR (0x0010ffff)

  typedef UCSCHAR *PUCSCHAR;
  typedef const UCSCHAR *PCUCSCHAR;
  typedef UCSCHAR *PUCSSTR;
  typedef UCSCHAR UNALIGNED *PUUCSSTR;
  typedef const UCSCHAR *PCUCSSTR;
  typedef const UCSCHAR UNALIGNED *PCUUCSSTR;
  typedef UCSCHAR UNALIGNED *PUUCSCHAR;
  typedef const UCSCHAR UNALIGNED *PCUUCSCHAR;
#endif

  typedef CHAR *PCHAR,*LPCH,*PCH;
  typedef CONST CHAR *LPCCH,*PCCH;
  typedef CHAR *NPSTR,*LPSTR,*PSTR;
  typedef PSTR *PZPSTR;
  typedef CONST PSTR *PCZPSTR;
  typedef CONST CHAR *LPCSTR,*PCSTR;
  typedef PCSTR *PZPCSTR;
  typedef CHAR *PZZSTR;
  typedef CONST CHAR *PCZZSTR;
  typedef CHAR *PNZCH;
  typedef CONST CHAR *PCNZCH;

#ifdef UNICODE
#ifndef _TCHAR_DEFINED
#define _TCHAR_DEFINED
  typedef WCHAR TCHAR, *PTCHAR;
  typedef WCHAR TBYTE, *PTBYTE;
#endif

  typedef LPWSTR LPTCH,PTCH;
  typedef LPWSTR PTSTR,LPTSTR;
  typedef LPCWSTR PCTSTR,LPCTSTR;
  typedef LPUWSTR PUTSTR,LPUTSTR;
  typedef LPCUWSTR PCUTSTR,LPCUTSTR;
  typedef LPWSTR LP;
  typedef PZZWSTR PZZTSTR;
  typedef PCZZWSTR PCZZTSTR;
  typedef PUZZWSTR PUZZTSTR;
  typedef PCUZZWSTR PCUZZTSTR;
  typedef PZPWSTR PZPTSTR;
  typedef PNZWCH PNZTCH;
  typedef PCNZWCH PCNZTCH;
  typedef PUNZWCH PUNZTCH;
  typedef PCUNZWCH PCUNZTCH;

#define __TEXT(quote) L##quote
#else
#ifndef _TCHAR_DEFINED
#define _TCHAR_DEFINED
  typedef char TCHAR, *PTCHAR;
  typedef unsigned char TBYTE, *PTBYTE;
#endif

  typedef LPSTR LPTCH,PTCH;
  typedef LPCCH LPCTCH,PCTCH;
  typedef LPSTR PTSTR,LPTSTR,PUTSTR,LPUTSTR;
  typedef LPCSTR PCTSTR,LPCTSTR,PCUTSTR,LPCUTSTR;
  typedef PZZSTR PZZTSTR, PUZZTSTR;
  typedef PCZZSTR PCZZTSTR, PCUZZTSTR;
  typedef PZPSTR PZPTSTR;
  typedef PNZCH PNZTCH, PUNZTCH;
  typedef PCNZCH PCNZTCH, PCUNZTCH;

#define __TEXT(quote) quote
#endif

#define TEXT(quote) __TEXT(quote)

  typedef SHORT *PSHORT;
  typedef LONG *PLONG;

#ifndef ___GROUP_AFFINITY_DEFINED
#define ___GROUP_AFFINITY_DEFINED
typedef struct _GROUP_AFFINITY {
  KAFFINITY Mask;
  WORD      Group;
  WORD      Reserved[3];
} GROUP_AFFINITY, *PGROUP_AFFINITY;
#endif /* !___GROUP_AFFINITY_DEFINED */

#ifdef STRICT
  typedef void *HANDLE;
#define DECLARE_HANDLE(name) struct name##__ { int unused; }; typedef struct name##__ *name
#else
typedef PVOID HANDLE;
#define DECLARE_HANDLE(name) typedef HANDLE name
#endif

  typedef HANDLE *PHANDLE;
  typedef BYTE FCHAR;
  typedef WORD FSHORT;
  typedef DWORD FLONG;

#ifndef _HRESULT_DEFINED
#define _HRESULT_DEFINED
  typedef LONG HRESULT;
#endif

#ifdef __cplusplus
#define EXTERN_C extern "C"
#else
#define EXTERN_C extern
#endif

/* Keep in sync with basetyps.h header.  */
#ifndef STDMETHODCALLTYPE
#define STDMETHODCALLTYPE WINAPI
#define STDMETHODVCALLTYPE __cdecl
#define STDAPICALLTYPE WINAPI
#define STDAPIVCALLTYPE __cdecl

#define STDAPI EXTERN_C HRESULT WINAPI
#define STDAPI_(type) EXTERN_C type WINAPI

#define STDMETHODIMP HRESULT WINAPI
#define STDMETHODIMP_(type) type WINAPI

#define STDAPIV EXTERN_C HRESULT STDAPIVCALLTYPE
#define STDAPIV_(type) EXTERN_C type STDAPIVCALLTYPE

#define STDMETHODIMPV HRESULT STDMETHODVCALLTYPE
#define STDMETHODIMPV_(type) type STDMETHODVCALLTYPE
#endif

#define IFACEMETHODIMP STDMETHODIMP
#define IFACEMETHODIMP_(type) STDMETHODIMP_(type)
#define IFACEMETHODIMPV STDMETHODIMPV
#define IFACEMETHODIMPV_(type) STDMETHODIMPV_(type)

  typedef char CCHAR;
#ifndef _LCID_DEFINED
#define _LCID_DEFINED
typedef DWORD LCID;
#endif
  typedef PDWORD PLCID;
#ifndef _LANGID_DEFINED
#define _LANGID_DEFINED
  typedef WORD LANGID;
#endif

#ifndef __COMPARTMENT_ID_DEFINED__
#define __COMPARTMENT_ID_DEFINED__

typedef enum {
  UNSPECIFIED_COMPARTMENT_ID = 0,
  DEFAULT_COMPARTMENT_ID
} COMPARTMENT_ID,*PCOMPARTMENT_ID;
#endif

#define APPLICATION_ERROR_MASK 0x20000000
#define ERROR_SEVERITY_SUCCESS 0x00000000
#define ERROR_SEVERITY_INFORMATIONAL 0x40000000
#define ERROR_SEVERITY_WARNING 0x80000000
#define ERROR_SEVERITY_ERROR 0xC0000000

#if defined (__ia64__) && !defined (__WIDL__)
  __declspec(align(16))
#endif
    typedef struct _FLOAT128 {
      __MINGW_EXTENSION __int64 LowPart;
      __MINGW_EXTENSION __int64 HighPart;
  } FLOAT128;

  typedef FLOAT128 *PFLOAT128;

#define _ULONGLONG_
  __MINGW_EXTENSION typedef __int64 LONGLONG;
  __MINGW_EXTENSION typedef unsigned __int64 ULONGLONG;

#define MAXLONGLONG (0x7fffffffffffffffll)

  typedef LONGLONG *PLONGLONG;
  typedef ULONGLONG *PULONGLONG;
  typedef LONGLONG USN;

#ifndef _LARGE_INTEGER_DEFINED
#define _LARGE_INTEGER_DEFINED

#if defined (__WIDL__)
typedef struct _LARGE_INTEGER {
#else
  typedef union _LARGE_INTEGER {
    __C89_NAMELESS struct {
      DWORD LowPart;
      LONG HighPart;
    } DUMMYSTRUCTNAME;
    struct {
      DWORD LowPart;
      LONG HighPart;
    } u;
#endif
    LONGLONG QuadPart;
  } LARGE_INTEGER;

  typedef LARGE_INTEGER *PLARGE_INTEGER;

#if defined (__WIDL__)
  typedef struct _ULARGE_INTEGER {
#else
  typedef union _ULARGE_INTEGER {
    __C89_NAMELESS struct {
      DWORD LowPart;
      DWORD HighPart;
    } DUMMYSTRUCTNAME;
    struct {
      DWORD LowPart;
      DWORD HighPart;
    } u;
#endif
    ULONGLONG QuadPart;
  } ULARGE_INTEGER;

  typedef ULARGE_INTEGER *PULARGE_INTEGER;

  typedef struct _LUID {
    DWORD LowPart;
    LONG HighPart;
  } LUID,*PLUID;

#endif /* _LARGE_INTEGER_DEFINED */

#define _DWORDLONG_
  typedef ULONGLONG DWORDLONG;
  typedef DWORDLONG *PDWORDLONG;

#define Int32x32To64(a, b) (((LONGLONG) ((LONG) (a))) * ((LONGLONG) ((LONG) (b))))
#define UInt32x32To64(a, b) (((ULONGLONG) ((unsigned int) (a))) *((ULONGLONG) ((unsigned int) (b))))
#define Int64ShllMod32(a, b) (((ULONGLONG) (a)) << (b))
#define Int64ShraMod32(a, b) (((LONGLONG) (a)) >> (b))
#define Int64ShrlMod32(a, b) (((ULONGLONG) (a)) >> (b))

#ifdef __cplusplus
  extern "C" {
#endif

#ifdef __x86_64

#define RotateLeft8 _rotl8
#define RotateLeft16 _rotl16
#define RotateRight8 _rotr8
#define RotateRight16 _rotr16

    unsigned char __cdecl _rotl8(unsigned char Value,unsigned char Shift);
    unsigned short __cdecl _rotl16(unsigned short Value,unsigned char Shift);
    unsigned char __cdecl _rotr8(unsigned char Value,unsigned char Shift);
    unsigned short __cdecl _rotr16(unsigned short Value,unsigned char Shift);
#endif /* __x86_64 */

#define RotateLeft32 _rotl
#define RotateLeft64 _rotl64
#define RotateRight32 _rotr
#define RotateRight64 _rotr64

#pragma push_macro ("_rotl")
#pragma push_macro ("_rotr")
#undef _rotl
#undef _rotr
    unsigned int __cdecl _rotl(unsigned int Value,int Shift);
    unsigned int __cdecl _rotr(unsigned int Value,int Shift);
#pragma pop_macro ("_rotr")
#pragma pop_macro ("_rotl")
#pragma push_macro ("_rotr64")
#pragma push_macro ("_rotl64")
#undef _rotl64
#undef _rotr64
    __MINGW_EXTENSION unsigned __int64 __cdecl _rotl64(unsigned __int64 Value,int Shift);
    __MINGW_EXTENSION unsigned __int64 __cdecl _rotr64(unsigned __int64 Value,int Shift);
#pragma pop_macro ("_rotl64")
#pragma pop_macro ("_rotr64")

#ifdef __cplusplus
  }
#endif

#define ANSI_NULL ((CHAR)0)
#define UNICODE_NULL ((WCHAR)0)
#define UNICODE_STRING_MAX_BYTES ((WORD) 65534)
#define UNICODE_STRING_MAX_CHARS (32767)

#ifndef _BOOLEAN_
#define _BOOLEAN_
  typedef BYTE BOOLEAN;
#endif
  typedef BOOLEAN *PBOOLEAN;

#ifndef _LIST_ENTRY_DEFINED
#define _LIST_ENTRY_DEFINED

  typedef struct _LIST_ENTRY {
    struct _LIST_ENTRY *Flink;
    struct _LIST_ENTRY *Blink;
  } LIST_ENTRY,*PLIST_ENTRY,*RESTRICTED_POINTER PRLIST_ENTRY;

  typedef struct _SINGLE_LIST_ENTRY {
    struct _SINGLE_LIST_ENTRY *Next;
  } SINGLE_LIST_ENTRY,*PSINGLE_LIST_ENTRY;

  typedef struct LIST_ENTRY32 {
    DWORD Flink;
    DWORD Blink;
  } LIST_ENTRY32;
  typedef LIST_ENTRY32 *PLIST_ENTRY32;

  typedef struct LIST_ENTRY64 {
    ULONGLONG Flink;
    ULONGLONG Blink;
  } LIST_ENTRY64;
  typedef LIST_ENTRY64 *PLIST_ENTRY64;

#endif /* _LIST_ENTRY_DEFINED */

#include <guiddef.h>

#ifndef __OBJECTID_DEFINED
#define __OBJECTID_DEFINED
  typedef struct _OBJECTID {
    GUID Lineage;
    DWORD Uniquifier;
  } OBJECTID;
#endif

#define MINCHAR 0x80
#define MAXCHAR 0x7f
#define MINSHORT 0x8000
#define MAXSHORT 0x7fff
#define MINLONG 0x80000000
#define MAXLONG 0x7fffffff
#define MAXBYTE 0xff
#define MAXWORD 0xffff
#define MAXDWORD 0xffffffff

#define FIELD_OFFSET(Type, Field) ((LONG) __builtin_offsetof(Type, Field))
#define RTL_FIELD_SIZE(type,field) (sizeof(((type *)0)->field))
#define RTL_SIZEOF_THROUGH_FIELD(type,field) (FIELD_OFFSET(type,field) + RTL_FIELD_SIZE(type,field))
#define RTL_CONTAINS_FIELD(Struct,Size,Field) ((((PCHAR)(&(Struct)->Field)) + sizeof((Struct)->Field)) <= (((PCHAR)(Struct))+(Size)))
#define RTL_NUMBER_OF_V1(A) (sizeof(A)/sizeof((A)[0]))
#define RTL_NUMBER_OF_V2(A) RTL_NUMBER_OF_V1(A)

#ifdef ENABLE_RTL_NUMBER_OF_V2
#define RTL_NUMBER_OF(A) RTL_NUMBER_OF_V2(A)
#else
#define RTL_NUMBER_OF(A) RTL_NUMBER_OF_V1(A)
#endif

#define ARRAYSIZE(A) RTL_NUMBER_OF_V2(A)
#define _ARRAYSIZE(A) RTL_NUMBER_OF_V1(A)

#define RTL_FIELD_TYPE(type,field) (((type*)0)->field)
#define RTL_NUMBER_OF_FIELD(type,field) (RTL_NUMBER_OF(RTL_FIELD_TYPE(type,field)))
#define RTL_PADDING_BETWEEN_FIELDS(T,F1,F2) ((FIELD_OFFSET(T,F2) > FIELD_OFFSET(T,F1)) ? (FIELD_OFFSET(T,F2) - FIELD_OFFSET(T,F1) - RTL_FIELD_SIZE(T,F1)) : (FIELD_OFFSET(T,F1) - FIELD_OFFSET(T,F2) - RTL_FIELD_SIZE(T,F2)))

#ifdef __cplusplus
#define RTL_CONST_CAST(type) const_cast<type>
#else
#define RTL_CONST_CAST(type) (type)
#endif

#ifdef __cplusplus
#define DEFINE_ENUM_FLAG_OPERATORS(ENUMTYPE) \
extern "C++" { \
inline ENUMTYPE operator | (ENUMTYPE a, ENUMTYPE b) { return ENUMTYPE(((int)a) | ((int)b)); } \
inline ENUMTYPE &operator |= (ENUMTYPE &a, ENUMTYPE b) { return (ENUMTYPE &)(((int &)a) |= ((int)b)); } \
inline ENUMTYPE operator & (ENUMTYPE a, ENUMTYPE b) { return ENUMTYPE(((int)a) & ((int)b)); } \
inline ENUMTYPE &operator &= (ENUMTYPE &a, ENUMTYPE b) { return (ENUMTYPE &)(((int &)a) &= ((int)b)); } \
inline ENUMTYPE operator ~ (ENUMTYPE a) { return ENUMTYPE(~((int)a)); } \
inline ENUMTYPE operator ^ (ENUMTYPE a, ENUMTYPE b) { return ENUMTYPE(((int)a) ^ ((int)b)); } \
inline ENUMTYPE &operator ^= (ENUMTYPE &a, ENUMTYPE b) { return (ENUMTYPE &)(((int &)a) ^= ((int)b)); } \
}
#else
#define DEFINE_ENUM_FLAG_OPERATORS(ENUMTYPE) /* */
#endif

#define COMPILETIME_OR_2FLAGS(a, b) ((UINT) (a) | (UINT) (b))
#define COMPILETIME_OR_3FLAGS(a, b, c) ((UINT) (a) | (UINT) (b) | (UINT) (c))
#define COMPILETIME_OR_4FLAGS(a, b, c, d) ((UINT) (a) | (UINT) (b) | (UINT) (c) | (UINT) (d))
#define COMPILETIME_OR_5FLAGS(a, b, c, d, e) ((UINT) (a) | (UINT) (b) | (UINT) (c) | (UINT) (d) | (UINT) (e))


#define RTL_BITS_OF(sizeOfArg) (sizeof(sizeOfArg) * 8)
#define RTL_BITS_OF_FIELD(type,field) (RTL_BITS_OF(RTL_FIELD_TYPE(type,field)))
#define CONTAINING_RECORD(address,type,field) ((type *)((PCHAR)(address) - (ULONG_PTR)(&((type *)0)->field)))

    typedef EXCEPTION_DISPOSITION NTAPI EXCEPTION_ROUTINE (struct _EXCEPTION_RECORD *ExceptionRecord, PVOID EstablisherFrame, struct _CONTEXT *ContextRecord, PVOID DispatcherContext);
#ifndef __PEXCEPTION_ROUTINE_DEFINED
#define __PEXCEPTION_ROUTINE_DEFINED
    typedef EXCEPTION_ROUTINE *PEXCEPTION_ROUTINE;
#endif

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

#define PRODUCT_UNDEFINED                         0x0

#define PRODUCT_ULTIMATE                          0x1
#define PRODUCT_HOME_BASIC                        0x2
#define PRODUCT_HOME_PREMIUM                      0x3
#define PRODUCT_ENTERPRISE                        0x4
#define PRODUCT_HOME_BASIC_N                      0x5
#define PRODUCT_BUSINESS                          0x6
#define PRODUCT_STANDARD_SERVER                   0x7
#define PRODUCT_DATACENTER_SERVER                 0x8
#define PRODUCT_SMALLBUSINESS_SERVER              0x9
#define PRODUCT_ENTERPRISE_SERVER                 0xa
#define PRODUCT_STARTER                           0xb
#define PRODUCT_DATACENTER_SERVER_CORE            0xc
#define PRODUCT_STANDARD_SERVER_CORE              0xd
#define PRODUCT_ENTERPRISE_SERVER_CORE            0xe
#define PRODUCT_ENTERPRISE_SERVER_IA64            0xf
#define PRODUCT_BUSINESS_N                        0x10
#define PRODUCT_WEB_SERVER                        0x11
#define PRODUCT_CLUSTER_SERVER                    0x12
#define PRODUCT_HOME_SERVER                       0x13
#define PRODUCT_STORAGE_EXPRESS_SERVER            0x14
#define PRODUCT_STORAGE_STANDARD_SERVER           0x15
#define PRODUCT_STORAGE_WORKGROUP_SERVER          0x16
#define PRODUCT_STORAGE_ENTERPRISE_SERVER         0x17
#define PRODUCT_SERVER_FOR_SMALLBUSINESS          0x18
#define PRODUCT_SMALLBUSINESS_SERVER_PREMIUM      0x19
#define PRODUCT_HOME_PREMIUM_N                    0x1a
#define PRODUCT_ENTERPRISE_N                      0x1b
#define PRODUCT_ULTIMATE_N                        0x1c
#define PRODUCT_WEB_SERVER_CORE                   0x1d
#define PRODUCT_MEDIUMBUSINESS_SERVER_MANAGEMENT  0x1e
#define PRODUCT_MEDIUMBUSINESS_SERVER_SECURITY    0x1f
#define PRODUCT_MEDIUMBUSINESS_SERVER_MESSAGING   0x20
#define PRODUCT_SERVER_FOUNDATION                 0x21
#define PRODUCT_HOME_PREMIUM_SERVER               0x22
#define PRODUCT_SERVER_FOR_SMALLBUSINESS_V        0x23
#define PRODUCT_STANDARD_SERVER_V                 0x24
#define PRODUCT_DATACENTER_SERVER_V               0x25
#define PRODUCT_SERVER_V                          0x25
#define PRODUCT_ENTERPRISE_SERVER_V               0x26
#define PRODUCT_DATACENTER_SERVER_CORE_V          0x27
#define PRODUCT_STANDARD_SERVER_CORE_V            0x28
#define PRODUCT_ENTERPRISE_SERVER_CORE_V          0x29
#define PRODUCT_HYPERV                            0x2a
#define PRODUCT_STORAGE_EXPRESS_SERVER_CORE       0x2b
#define PRODUCT_STORAGE_STANDARD_SERVER_CORE      0x2c
#define PRODUCT_STORAGE_WORKGROUP_SERVER_CORE     0x2d
#define PRODUCT_STORAGE_ENTERPRISE_SERVER_CORE    0x2e
#define PRODUCT_STARTER_N                         0x2f
#define PRODUCT_PROFESSIONAL                      0x30
#define PRODUCT_PROFESSIONAL_N                    0x31
#define PRODUCT_SB_SOLUTION_SERVER                0x32
#define PRODUCT_SERVER_FOR_SB_SOLUTIONS           0x33
#define PRODUCT_STANDARD_SERVER_SOLUTIONS         0x34
#define PRODUCT_STANDARD_SERVER_SOLUTIONS_CORE    0x35
#define PRODUCT_SB_SOLUTION_SERVER_EM             0x36
#define PRODUCT_SERVER_FOR_SB_SOLUTIONS_EM        0x37
#define PRODUCT_SOLUTION_EMBEDDEDSERVER           0x38
#define PRODUCT_SOLUTION_EMBEDDEDSERVER_CORE      0x39
#define PRODUCT_PROFESSIONAL_EMBEDDED             0x3A
#define PRODUCT_ESSENTIALBUSINESS_SERVER_MGMT     0x3B
#define PRODUCT_ESSENTIALBUSINESS_SERVER_ADDL     0x3C
#define PRODUCT_ESSENTIALBUSINESS_SERVER_MGMTSVC  0x3D
#define PRODUCT_ESSENTIALBUSINESS_SERVER_ADDLSVC  0x3E
#define PRODUCT_SMALLBUSINESS_SERVER_PREMIUM_CORE 0x3f
#define PRODUCT_CLUSTER_SERVER_V                  0x40
#define PRODUCT_EMBEDDED                          0x41
#define PRODUCT_STARTER_E                         0x42
#define PRODUCT_HOME_BASIC_E                      0x43
#define PRODUCT_HOME_PREMIUM_E                    0x44
#define PRODUCT_PROFESSIONAL_E                    0x45
#define PRODUCT_ENTERPRISE_E                      0x46
#define PRODUCT_ULTIMATE_E                        0x47
#define PRODUCT_ENTERPRISE_EVALUATION             0x48
#define PRODUCT_MULTIPOINT_STANDARD_SERVER        0x4C
#define PRODUCT_MULTIPOINT_PREMIUM_SERVER         0x4D
#define PRODUCT_STANDARD_EVALUATION_SERVER        0x4F
#define PRODUCT_DATACENTER_EVALUATION_SERVER      0x50
#define PRODUCT_ENTERPRISE_N_EVALUATION           0x54
#define PRODUCT_EMBEDDED_AUTOMOTIVE               0x55
#define PRODUCT_EMBEDDED_INDUSTRY_A               0x56
#define PRODUCT_THINPC                            0x57
#define PRODUCT_EMBEDDED_A                        0x58
#define PRODUCT_EMBEDDED_INDUSTRY                 0x59
#define PRODUCT_EMBEDDED_E                        0x5A
#define PRODUCT_EMBEDDED_INDUSTRY_E               0x5B
#define PRODUCT_EMBEDDED_INDUSTRY_A_E             0x5C
#define PRODUCT_STORAGE_WORKGROUP_EVALUATION_SERVER 0x5F
#define PRODUCT_STORAGE_STANDARD_EVALUATION_SERVER  0x60
#define PRODUCT_CORE_ARM                          0x61
#define PRODUCT_CORE_N                            0x62
#define PRODUCT_CORE_COUNTRYSPECIFIC              0x63
#define PRODUCT_CORE_SINGLELANGUAGE               0x64
#define PRODUCT_CORE_LANGUAGESPECIFIC             0x64
#define PRODUCT_CORE                              0x65
#define PRODUCT_PROFESSIONAL_WMC                  0x67
#define PRODUCT_MOBILE_CORE                       0x68
#define PRODUCT_EMBEDDED_INDUSTRY_EVAL            0x69
#define PRODUCT_EMBEDDED_INDUSTRY_E_EVAL          0x6A
#define PRODUCT_EMBEDDED_EVAL                     0x6B
#define PRODUCT_EMBEDDED_E_EVAL                   0x6C
#define PRODUCT_NANO_SERVER                       0x6D
#define PRODUCT_CLOUD_STORAGE_SERVER              0x6E
#define PRODUCT_CORE_CONNECTED                    0x6F
#define PRODUCT_PROFESSIONAL_STUDENT              0x70
#define PRODUCT_CORE_CONNECTED_N                  0x71
#define PRODUCT_PROFESSIONAL_STUDENT_N            0x72
#define PRODUCT_CORE_CONNECTED_SINGLELANGUAGE     0x73
#define PRODUCT_CORE_CONNECTED_COUNTRYSPECIFIC    0x74
#define PRODUCT_CONNECTED_CAR                     0x75
#define PRODUCT_INDUSTRY_HANDHELD                 0x76
#define PRODUCT_PPI_PRO                           0x77
#define PRODUCT_ARM64_SERVER                      0x78
#define PRODUCT_EDUCATION                         0x79
#define PRODUCT_EDUCATION_N                       0x7a
#define PRODUCT_IOTUAP                            0x7B
#define PRODUCT_CLOUD_HOST_INFRASTRUCTURE_SERVER  0x7C
#define PRODUCT_ENTERPRISE_S                      0x7D
#define PRODUCT_ENTERPRISE_S_N                    0x7E
#define PRODUCT_PROFESSIONAL_S                    0x7F
#define PRODUCT_PROFESSIONAL_S_N                  0x80
#define PRODUCT_ENTERPRISE_S_EVALUATION           0x81
#define PRODUCT_ENTERPRISE_S_N_EVALUATION         0x82
#define PRODUCT_MOBILE_ENTERPRISE                 0x85

#define PRODUCT_UNLICENSED                        0xabcdabcd

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
#define LANG_AZERBAIJANI			  0x2c
#define LANG_BANGLA				  0x45
#define LANG_BASHKIR                              0x6d
#define LANG_BASQUE                               0x2d
#define LANG_BELARUSIAN                           0x23
#define LANG_BENGALI                              0x45
#define LANG_BRETON                               0x7e
#define LANG_BOSNIAN                              0x1a
#define LANG_BOSNIAN_NEUTRAL                    0x781a
#define LANG_BULGARIAN                            0x02
#define LANG_CATALAN                              0x03
#define LANG_CENTRAL_KURDISH			  0x92
#define LANG_CHEROKEE				  0x5c
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
#define LANG_FULAH				  0x67
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
#define LANG_ODIA				  0x48
#define LANG_ORIYA                                0x48
#define LANG_PASHTO                               0x63
#define LANG_PERSIAN                              0x29
#define LANG_POLISH                               0x15
#define LANG_PORTUGUESE                           0x16
#define LANG_PULAR				  0x67
#define LANG_PUNJABI                              0x46
#define LANG_QUECHUA                              0x6b
#define LANG_ROMANIAN                             0x18
#define LANG_ROMANSH                              0x17
#define LANG_RUSSIAN                              0x19
#define LANG_SAKHA				  0x85
#define LANG_SAMI                                 0x3b
#define LANG_SANSKRIT                             0x4f
#define LANG_SCOTTISH_GAELIC			  0x91
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
#define LANG_TIGRINYA				  0x73
#define LANG_TSWANA                               0x32
#define LANG_TURKISH                              0x1f
#define LANG_TURKMEN                              0x42
#define LANG_UIGHUR                               0x80
#define LANG_UKRAINIAN                            0x22
#define LANG_UPPER_SORBIAN                        0x2e
#define LANG_URDU                                 0x20
#define LANG_UZBEK                                0x43
#define LANG_VALENCIAN				  0x03
#define LANG_VIETNAMESE                           0x2a
#define LANG_WELSH                                0x52
#define LANG_WOLOF                                0x88
#define LANG_XHOSA                                0x34
#define LANG_YAKUT                                0x85
#define LANG_YI                                   0x78
#define LANG_YORUBA                               0x6a
#define LANG_ZULU                                 0x35

#define SUBLANG_NEUTRAL                           0x00
#define SUBLANG_DEFAULT                           0x01
#define SUBLANG_SYS_DEFAULT                       0x02
#define SUBLANG_CUSTOM_DEFAULT                    0x03
#define SUBLANG_CUSTOM_UNSPECIFIED                0x04
#define SUBLANG_UI_CUSTOM_DEFAULT                 0x05

#define SUBLANG_AFRIKAANS_SOUTH_AFRICA            0x01
#define SUBLANG_ALBANIAN_ALBANIA                  0x01
#define SUBLANG_ALSATIAN_FRANCE                   0x01
#define SUBLANG_AMHARIC_ETHIOPIA                  0x01
#define SUBLANG_ARABIC_SAUDI_ARABIA               0x01
#define SUBLANG_ARABIC_IRAQ                       0x02
#define SUBLANG_ARABIC_EGYPT                      0x03
#define SUBLANG_ARABIC_LIBYA                      0x04
#define SUBLANG_ARABIC_ALGERIA                    0x05
#define SUBLANG_ARABIC_MOROCCO                    0x06
#define SUBLANG_ARABIC_TUNISIA                    0x07
#define SUBLANG_ARABIC_OMAN                       0x08
#define SUBLANG_ARABIC_YEMEN                      0x09
#define SUBLANG_ARABIC_SYRIA                      0x0a
#define SUBLANG_ARABIC_JORDAN                     0x0b
#define SUBLANG_ARABIC_LEBANON                    0x0c
#define SUBLANG_ARABIC_KUWAIT                     0x0d
#define SUBLANG_ARABIC_UAE                        0x0e
#define SUBLANG_ARABIC_BAHRAIN                    0x0f
#define SUBLANG_ARABIC_QATAR                      0x10
#define SUBLANG_ARMENIAN_ARMENIA                  0x01
#define SUBLANG_ASSAMESE_INDIA                    0x01
#define SUBLANG_AZERI_LATIN                       0x01
#define SUBLANG_AZERI_CYRILLIC                    0x02
#define SUBLANG_AZERBAIJANI_AZERBAIJAN_LATIN      0x01
#define SUBLANG_AZERBAIJANI_AZERBAIJAN_CYRILLIC   0x02
#define SUBLANG_BANGLA_INDIA                      0x01
#define SUBLANG_BANGLA_BANGLADESH                 0x02
#define SUBLANG_BASHKIR_RUSSIA                    0x01
#define SUBLANG_BASQUE_BASQUE                     0x01
#define SUBLANG_BELARUSIAN_BELARUS                0x01
#define SUBLANG_BENGALI_INDIA                     0x01
#define SUBLANG_BENGALI_BANGLADESH                0x02
#define SUBLANG_BOSNIAN_BOSNIA_HERZEGOVINA_LATIN  0x05
#define SUBLANG_BOSNIAN_BOSNIA_HERZEGOVINA_CYRILLIC 0x08
#define SUBLANG_BRETON_FRANCE                     0x01
#define SUBLANG_BULGARIAN_BULGARIA                0x01
#define SUBLANG_CATALAN_CATALAN                   0x01
#define SUBLANG_CENTRAL_KURDISH_IRAQ              0x01
#define SUBLANG_CHEROKEE_CHEROKEE                 0x01
#define SUBLANG_CHINESE_TRADITIONAL               0x01
#define SUBLANG_CHINESE_SIMPLIFIED                0x02
#define SUBLANG_CHINESE_HONGKONG                  0x03
#define SUBLANG_CHINESE_SINGAPORE                 0x04
#define SUBLANG_CHINESE_MACAU                     0x05
#define SUBLANG_CORSICAN_FRANCE                   0x01
#define SUBLANG_CZECH_CZECH_REPUBLIC              0x01
#define SUBLANG_CROATIAN_CROATIA                  0x01
#define SUBLANG_CROATIAN_BOSNIA_HERZEGOVINA_LATIN 0x04
#define SUBLANG_DANISH_DENMARK                    0x01
#define SUBLANG_DARI_AFGHANISTAN                  0x01
#define SUBLANG_DIVEHI_MALDIVES                   0x01
#define SUBLANG_DUTCH                             0x01
#define SUBLANG_DUTCH_BELGIAN                     0x02
#define SUBLANG_ENGLISH_US                        0x01
#define SUBLANG_ENGLISH_UK                        0x02
#define SUBLANG_ENGLISH_AUS                       0x03
#define SUBLANG_ENGLISH_CAN                       0x04
#define SUBLANG_ENGLISH_NZ                        0x05
#define SUBLANG_ENGLISH_IRELAND                   0x06
#define SUBLANG_ENGLISH_EIRE                      0x06
#define SUBLANG_ENGLISH_SOUTH_AFRICA              0x07
#define SUBLANG_ENGLISH_JAMAICA                   0x08
#define SUBLANG_ENGLISH_CARIBBEAN                 0x09
#define SUBLANG_ENGLISH_BELIZE                    0x0a
#define SUBLANG_ENGLISH_TRINIDAD                  0x0b
#define SUBLANG_ENGLISH_ZIMBABWE                  0x0c
#define SUBLANG_ENGLISH_PHILIPPINES               0x0d
#define SUBLANG_ENGLISH_INDIA                     0x10
#define SUBLANG_ENGLISH_MALAYSIA                  0x11
#define SUBLANG_ENGLISH_SINGAPORE                 0x12
#define SUBLANG_ESTONIAN_ESTONIA                  0x01
#define SUBLANG_FAEROESE_FAROE_ISLANDS            0x01
#define SUBLANG_FILIPINO_PHILIPPINES              0x01
#define SUBLANG_FINNISH_FINLAND                   0x01
#define SUBLANG_FRENCH                            0x01
#define SUBLANG_FRENCH_BELGIAN                    0x02
#define SUBLANG_FRENCH_CANADIAN                   0x03
#define SUBLANG_FRENCH_SWISS                      0x04
#define SUBLANG_FRENCH_LUXEMBOURG                 0x05
#define SUBLANG_FRENCH_MONACO                     0x06
#define SUBLANG_FRISIAN_NETHERLANDS               0x01
#define SUBLANG_FULAH_SENEGAL                     0x02
#define SUBLANG_GALICIAN_GALICIAN                 0x01
#define SUBLANG_GEORGIAN_GEORGIA                  0x01
#define SUBLANG_GERMAN                            0x01
#define SUBLANG_GERMAN_SWISS                      0x02
#define SUBLANG_GERMAN_AUSTRIAN                   0x03
#define SUBLANG_GERMAN_LUXEMBOURG                 0x04
#define SUBLANG_GERMAN_LIECHTENSTEIN              0x05
#define SUBLANG_GREEK_GREECE                      0x01
#define SUBLANG_GREENLANDIC_GREENLAND             0x01
#define SUBLANG_GUJARATI_INDIA                    0x01
#define SUBLANG_HAUSA_NIGERIA_LATIN               0x01
#define SUBLANG_HAUSA_NIGERIA    SUBLANG_HAUSA_NIGERIA_LATIN	/* SUBLANG_HAUSA_NIGERIA_LATIN is what MS defines */
#define SUBLANG_HAWAIIAN_US                       0x01
#define SUBLANG_HEBREW_ISRAEL                     0x01
#define SUBLANG_HINDI_INDIA                       0x01
#define SUBLANG_HUNGARIAN_HUNGARY                 0x01
#define SUBLANG_ICELANDIC_ICELAND                 0x01
#define SUBLANG_IGBO_NIGERIA                      0x01
#define SUBLANG_INDONESIAN_INDONESIA              0x01
#define SUBLANG_INUKTITUT_CANADA                  0x01
#define SUBLANG_INUKTITUT_CANADA_LATIN            0x02
#define SUBLANG_IRISH_IRELAND                     0x02
#define SUBLANG_ITALIAN                           0x01
#define SUBLANG_ITALIAN_SWISS                     0x02
#define SUBLANG_JAPANESE_JAPAN                    0x01
#define SUBLANG_KANNADA_INDIA                     0x01
#define SUBLANG_KASHMIRI_INDIA                    0x02
#define SUBLANG_KASHMIRI_SASIA                    0x02
#define SUBLANG_KAZAK_KAZAKHSTAN                  0x01
#define SUBLANG_KHMER_CAMBODIA                    0x01
#define SUBLANG_KICHE_GUATEMALA                   0x01
#define SUBLANG_KINYARWANDA_RWANDA                0x01
#define SUBLANG_KONKANI_INDIA                     0x01
#define SUBLANG_KOREAN                            0x01
#define SUBLANG_KYRGYZ_KYRGYZSTAN                 0x01
#define SUBLANG_LAO_LAO                           0x01
#define SUBLANG_LAO_LAO_PDR            SUBLANG_LAO_LAO		/* SUBLANG_LAO_LAO is what MS defines */
#define SUBLANG_LATVIAN_LATVIA                    0x01
#if (WINVER >= 0x0600)
#define SUBLANG_LITHUANIAN_LITHUANIA              0x01
#endif /* WINVER >= 0x0600 */
#define SUBLANG_LITHUANIAN                        0x01
#define SUBLANG_LOWER_SORBIAN_GERMANY             0x02
#define SUBLANG_LUXEMBOURGISH_LUXEMBOURG          0x01
#define SUBLANG_MACEDONIAN_MACEDONIA              0x01
#define SUBLANG_MALAY_MALAYSIA                    0x01
#define SUBLANG_MALAY_BRUNEI_DARUSSALAM           0x02
#define SUBLANG_MALAYALAM_INDIA                   0x01
#define SUBLANG_MALTESE_MALTA                     0x01
#define SUBLANG_MAORI_NEW_ZEALAND                 0x01
#define SUBLANG_MAPUDUNGUN_CHILE                  0x01
#define SUBLANG_MARATHI_INDIA                     0x01
#define SUBLANG_MOHAWK_MOHAWK                     0x01
#define SUBLANG_MONGOLIAN_CYRILLIC_MONGOLIA       0x01
#define SUBLANG_MONGOLIAN_PRC                     0x02
#define SUBLANG_NEPALI_NEPAL                      0x01
#define SUBLANG_NEPALI_INDIA                      0x02
#define SUBLANG_NORWEGIAN_BOKMAL                  0x01
#define SUBLANG_NORWEGIAN_NYNORSK                 0x02
#define SUBLANG_OCCITAN_FRANCE                    0x01
#define SUBLANG_ORIYA_INDIA                       0x01
#define SUBLANG_PASHTO_AFGHANISTAN                0x01
#define SUBLANG_PERSIAN_IRAN                      0x01
#define SUBLANG_POLISH_POLAND                     0x01
#define SUBLANG_PORTUGUESE_BRAZILIAN              0x01
#if (WINVER >= 0x0600)
#define SUBLANG_PORTUGUESE_PORTUGAL               0x02
#endif /* WINVER >= 0x0600 */
#define SUBLANG_PORTUGUESE                        0x02
#define SUBLANG_PULAR_SENEGAL                     0x02
#define SUBLANG_PUNJABI_INDIA                     0x01
#define SUBLANG_PUNJABI_PAKISTAN                  0x02
#define SUBLANG_QUECHUA_BOLIVIA                   0x01
#define SUBLANG_QUECHUA_ECUADOR                   0x02
#define SUBLANG_QUECHUA_PERU                      0x03
#define SUBLANG_ROMANIAN_ROMANIA                  0x01
/* ??? #define SUBLANG_ROMANIAN_MOLDOVA                  0x01 ??? */
#define SUBLANG_ROMANSH_SWITZERLAND               0x01
#define SUBLANG_RUSSIAN_RUSSIA                    0x01
#define SUBLANG_SAKHA_RUSSIA                      0x01
#define SUBLANG_SAMI_NORTHERN_NORWAY              0x01
#define SUBLANG_SAMI_NORTHERN_SWEDEN              0x02
#define SUBLANG_SAMI_NORTHERN_FINLAND             0x03
#define SUBLANG_SAMI_LULE_NORWAY                  0x04
#define SUBLANG_SAMI_LULE_SWEDEN                  0x05
#define SUBLANG_SAMI_SOUTHERN_NORWAY              0x06
#define SUBLANG_SAMI_SOUTHERN_SWEDEN              0x07
#define SUBLANG_SAMI_SKOLT_FINLAND                0x08
#define SUBLANG_SAMI_INARI_FINLAND                0x09
#define SUBLANG_SANSKRIT_INDIA                    0x01
#define SUBLANG_SCOTTISH_GAELIC                    0x01
#define SUBLANG_SERBIAN_LATIN                     0x02
#define SUBLANG_SERBIAN_CYRILLIC                  0x03
#define SUBLANG_SERBIAN_BOSNIA_HERZEGOVINA_LATIN  0x06
#define SUBLANG_SERBIAN_BOSNIA_HERZEGOVINA_CYRILLIC 0x07
#define SUBLANG_SERBIAN_MONTENEGRO_LATIN          0x0b
#define SUBLANG_SERBIAN_MONTENEGRO_CYRILLIC       0x0c
#define SUBLANG_SERBIAN_SERBIA_LATIN              0x09
#define SUBLANG_SERBIAN_SERBIA_CYRILLIC           0x0a
#define SUBLANG_SINDHI_INDIA                      0x01
#define SUBLANG_SINDHI_AFGHANISTAN                0x02
#define SUBLANG_SINDHI_PAKISTAN                   0x02
#define SUBLANG_SINHALESE_SRI_LANKA               0x01
#define SUBLANG_SOTHO_NORTHERN_SOUTH_AFRICA       0x01
#define SUBLANG_SLOVAK_SLOVAKIA                   0x01
#define SUBLANG_SLOVENIAN_SLOVENIA                0x01
#define SUBLANG_SPANISH                           0x01
#define SUBLANG_SPANISH_MEXICAN                   0x02
#define SUBLANG_SPANISH_MODERN                    0x03
#define SUBLANG_SPANISH_GUATEMALA                 0x04
#define SUBLANG_SPANISH_COSTA_RICA                0x05
#define SUBLANG_SPANISH_PANAMA                    0x06
#define SUBLANG_SPANISH_DOMINICAN_REPUBLIC        0x07
#define SUBLANG_SPANISH_VENEZUELA                 0x08
#define SUBLANG_SPANISH_COLOMBIA                  0x09
#define SUBLANG_SPANISH_PERU                      0x0a
#define SUBLANG_SPANISH_ARGENTINA                 0x0b
#define SUBLANG_SPANISH_ECUADOR                   0x0c
#define SUBLANG_SPANISH_CHILE                     0x0d
#define SUBLANG_SPANISH_URUGUAY                   0x0e
#define SUBLANG_SPANISH_PARAGUAY                  0x0f
#define SUBLANG_SPANISH_BOLIVIA                   0x10
#define SUBLANG_SPANISH_EL_SALVADOR               0x11
#define SUBLANG_SPANISH_HONDURAS                  0x12
#define SUBLANG_SPANISH_NICARAGUA                 0x13
#define SUBLANG_SPANISH_PUERTO_RICO               0x14
#define SUBLANG_SPANISH_US                        0x15
#define SUBLANG_SWAHILI_KENYA                     0x01
#if (WINVER >= 0x0600)
#define SUBLANG_SWEDISH_SWEDEN                    0x01
#endif /* WINVER >= 0x0600 */
#define SUBLANG_SWEDISH                           0x01
#define SUBLANG_SWEDISH_FINLAND                   0x02
#define SUBLANG_SYRIAC                            0x01
#define SUBLANG_SYRIAC_SYRIA            SUBLANG_SYRIAC		/* SUBLANG_SYRIAC_SYRIA is what MSDN mentions */
#define SUBLANG_TAJIK_TAJIKISTAN                  0x01
#define SUBLANG_TAMAZIGHT_ALGERIA_LATIN           0x02
#define SUBLANG_TAMAZIGHT_MOROCCO_TIFINAGH        0x04
#define SUBLANG_TAMIL_INDIA                       0x01
#define SUBLANG_TAMIL_SRI_LANKA                   0x02
#define SUBLANG_TATAR_RUSSIA                      0x01
#define SUBLANG_TELUGU_INDIA                      0x01
#define SUBLANG_THAI_THAILAND                     0x01
#define SUBLANG_TIBETAN_PRC                       0x01
#define SUBLANG_TIBETAN_BHUTAN                    0x02
#define SUBLANG_TIGRIGNA_ERITREA                  0x02
#define SUBLANG_TIGRINYA_ERITREA                  0x02
#define SUBLANG_TIGRINYA_ETHIOPIA                 0x01
#define SUBLANG_TSWANA_BOTSWANA                   0x02
#define SUBLANG_TSWANA_SOUTH_AFRICA               0x01
#define SUBLANG_TURKISH_TURKEY                    0x01
#define SUBLANG_TURKMEN_TURKMENISTAN              0x01
#define SUBLANG_UIGHUR_PRC                        0x01
#define SUBLANG_UKRAINIAN_UKRAINE                 0x01
#define SUBLANG_UPPER_SORBIAN_GERMANY             0x01
#define SUBLANG_URDU_PAKISTAN                     0x01
#define SUBLANG_URDU_INDIA                        0x02
#define SUBLANG_UZBEK_LATIN                       0x01
#define SUBLANG_UZBEK_CYRILLIC                    0x02
#define SUBLANG_VALENCIAN_VALENCIA                0x02
#define SUBLANG_VIETNAMESE_VIETNAM                0x01
#define SUBLANG_WELSH_UNITED_KINGDOM              0x01
#define SUBLANG_WOLOF_SENEGAL                     0x01
#define SUBLANG_YORUBA_NIGERIA                    0x01
#define SUBLANG_XHOSA_SOUTH_AFRICA                0x01
#define SUBLANG_YAKUT_RUSSIA                      0x01
#define SUBLANG_YI_PRC                            0x01
#define SUBLANG_ZULU_SOUTH_AFRICA                 0x01

#define SORT_DEFAULT                              0x0
#define SORT_INVARIANT_MATH                       0x1

#define SORT_JAPANESE_XJIS                        0x0
#define SORT_JAPANESE_UNICODE                     0x1
#define SORT_JAPANESE_RADICALSTROKE               0x4

#define SORT_CHINESE_BIG5                         0x0
#define SORT_CHINESE_PRCP                         0x0
#define SORT_CHINESE_UNICODE                      0x1
#define SORT_CHINESE_PRC                          0x2
#define SORT_CHINESE_BOPOMOFO                     0x3
#define SORT_CHINESE_RADICALSTROKE		  0x4

#define SORT_KOREAN_KSC                           0x0
#define SORT_KOREAN_UNICODE                       0x1

#define SORT_GERMAN_PHONE_BOOK                    0x1

#define SORT_HUNGARIAN_DEFAULT                    0x0
#define SORT_HUNGARIAN_TECHNICAL                  0x1

#define SORT_GEORGIAN_TRADITIONAL                 0x0
#define SORT_GEORGIAN_MODERN                      0x1

#define MAKELANGID(p,s) ((((WORD)(s)) << 10) | (WORD)(p))
#define PRIMARYLANGID(lgid) ((WORD)(lgid) & 0x3ff)
#define SUBLANGID(lgid) ((WORD)(lgid) >> 10)

#define NLS_VALID_LOCALE_MASK 0x000fffff

#define MAKELCID(lgid,srtid) ((DWORD)((((DWORD)((WORD)(srtid))) << 16) | ((DWORD)((WORD)(lgid)))))
#define MAKESORTLCID(lgid,srtid,ver) ((DWORD)((MAKELCID(lgid,srtid)) | (((DWORD)((WORD)(ver))) << 20)))
#define LANGIDFROMLCID(lcid) ((WORD)(lcid))
#define SORTIDFROMLCID(lcid) ((WORD)((((DWORD)(lcid)) >> 16) & 0xf))
#define SORTVERSIONFROMLCID(lcid) ((WORD)((((DWORD)(lcid)) >> 20) & 0xf))

#define LOCALE_NAME_MAX_LENGTH 85
#define LANG_SYSTEM_DEFAULT (MAKELANGID(LANG_NEUTRAL,SUBLANG_SYS_DEFAULT))
#define LANG_USER_DEFAULT (MAKELANGID(LANG_NEUTRAL,SUBLANG_DEFAULT))

#define LOCALE_SYSTEM_DEFAULT (MAKELCID(LANG_SYSTEM_DEFAULT,SORT_DEFAULT))
#define LOCALE_USER_DEFAULT (MAKELCID(LANG_USER_DEFAULT,SORT_DEFAULT))

#define LOCALE_NEUTRAL (MAKELCID(MAKELANGID(LANG_NEUTRAL,SUBLANG_NEUTRAL),SORT_DEFAULT))

#define LOCALE_CUSTOM_DEFAULT (MAKELCID(MAKELANGID(LANG_NEUTRAL, SUBLANG_CUSTOM_DEFAULT), SORT_DEFAULT))
#define LOCALE_CUSTOM_UNSPECIFIED (MAKELCID(MAKELANGID(LANG_NEUTRAL, SUBLANG_CUSTOM_UNSPECIFIED), SORT_DEFAULT))
#define LOCALE_CUSTOM_UI_DEFAULT (MAKELCID(MAKELANGID(LANG_NEUTRAL, SUBLANG_UI_CUSTOM_DEFAULT), SORT_DEFAULT))

#define LOCALE_INVARIANT (MAKELCID(MAKELANGID(LANG_INVARIANT,SUBLANG_NEUTRAL),SORT_DEFAULT))

#define UNREFERENCED_PARAMETER(P) {(P) = (P);}
#define UNREFERENCED_LOCAL_VARIABLE(V) {(V) = (V);}
#define DBG_UNREFERENCED_PARAMETER(P) (P)
#define DBG_UNREFERENCED_LOCAL_VARIABLE(V) (V)

#define DEFAULT_UNREACHABLE

#ifndef UMDF_USING_NTSTATUS
#ifndef WIN32_NO_STATUS
#define STATUS_WAIT_0 ((DWORD)0x00000000)
#define STATUS_ABANDONED_WAIT_0 ((DWORD)0x00000080)
#define STATUS_USER_APC ((DWORD)0x000000C0)
#define STATUS_TIMEOUT ((DWORD)0x00000102)
#define STATUS_PENDING ((DWORD)0x00000103)
#define DBG_EXCEPTION_HANDLED ((DWORD)0x00010001)
#define DBG_CONTINUE ((DWORD)0x00010002)
#define STATUS_SEGMENT_NOTIFICATION ((DWORD)0x40000005)
#define STATUS_FATAL_APP_EXIT ((DWORD)0x40000015)
#define DBG_TERMINATE_THREAD ((DWORD)0x40010003)
#define DBG_TERMINATE_PROCESS ((DWORD)0x40010004)
#define DBG_CONTROL_C ((DWORD)0x40010005)
#define DBG_PRINTEXCEPTION_C ((DWORD)0x40010006)
#define DBG_RIPEXCEPTION ((DWORD)0x40010007)
#define DBG_CONTROL_BREAK ((DWORD)0x40010008)
#define DBG_COMMAND_EXCEPTION ((DWORD)0x40010009)
#define DBG_PRINTEXCEPTION_WIDE_C ((DWORD)0x4001000A)
#define STATUS_GUARD_PAGE_VIOLATION ((DWORD)0x80000001)
#define STATUS_DATATYPE_MISALIGNMENT ((DWORD)0x80000002)
#define STATUS_BREAKPOINT ((DWORD)0x80000003)
#define STATUS_SINGLE_STEP ((DWORD)0x80000004)
#define STATUS_LONGJUMP ((DWORD)0x80000026)
#define STATUS_UNWIND_CONSOLIDATE ((DWORD)0x80000029)
#define DBG_EXCEPTION_NOT_HANDLED ((DWORD)0x80010001)
#define STATUS_ACCESS_VIOLATION ((DWORD)0xC0000005)
#define STATUS_IN_PAGE_ERROR ((DWORD)0xC0000006)
#define STATUS_INVALID_HANDLE ((DWORD)0xC0000008)
#define STATUS_INVALID_PARAMETER ((DWORD)0xC000000D)
#define STATUS_NO_MEMORY ((DWORD)0xC0000017)
#define STATUS_ILLEGAL_INSTRUCTION ((DWORD)0xC000001D)
#define STATUS_NONCONTINUABLE_EXCEPTION ((DWORD)0xC0000025)
#define STATUS_INVALID_DISPOSITION ((DWORD)0xC0000026)
#define STATUS_ARRAY_BOUNDS_EXCEEDED ((DWORD)0xC000008C)
#define STATUS_FLOAT_DENORMAL_OPERAND ((DWORD)0xC000008D)
#define STATUS_FLOAT_DIVIDE_BY_ZERO ((DWORD)0xC000008E)
#define STATUS_FLOAT_INEXACT_RESULT ((DWORD)0xC000008F)
#define STATUS_FLOAT_INVALID_OPERATION ((DWORD)0xC0000090)
#define STATUS_FLOAT_OVERFLOW ((DWORD)0xC0000091)
#define STATUS_FLOAT_STACK_CHECK ((DWORD)0xC0000092)
#define STATUS_FLOAT_UNDERFLOW ((DWORD)0xC0000093)
#define STATUS_INTEGER_DIVIDE_BY_ZERO ((DWORD)0xC0000094)
#define STATUS_INTEGER_OVERFLOW ((DWORD)0xC0000095)
#define STATUS_PRIVILEGED_INSTRUCTION ((DWORD)0xC0000096)
#define STATUS_STACK_OVERFLOW ((DWORD)0xC00000FD)
#define STATUS_DLL_NOT_FOUND ((DWORD)0xC0000135)
#define STATUS_ORDINAL_NOT_FOUND ((DWORD)0xC0000138)
#define STATUS_ENTRYPOINT_NOT_FOUND ((DWORD)0xC0000139)
#define STATUS_CONTROL_C_EXIT ((DWORD)0xC000013A)
#define STATUS_DLL_INIT_FAILED ((DWORD)0xC0000142)
#define STATUS_FLOAT_MULTIPLE_FAULTS ((DWORD)0xC00002B4)
#define STATUS_FLOAT_MULTIPLE_TRAPS ((DWORD)0xC00002B5)
#define STATUS_REG_NAT_CONSUMPTION ((DWORD)0xC00002C9)
#define STATUS_HEAP_CORRUPTION ((DWORD)0xC0000374)
#define STATUS_STACK_BUFFER_OVERRUN ((DWORD)0xC0000409)
#define STATUS_INVALID_CRUNTIME_PARAMETER ((DWORD)0xC0000417)
#define STATUS_ASSERTION_FAILURE ((DWORD)0xC0000420)
#define STATUS_SXS_EARLY_DEACTIVATION ((DWORD)0xC015000F)
#define STATUS_SXS_INVALID_DEACTIVATION ((DWORD)0xC0150010)
#endif
#endif

#define MAXIMUM_WAIT_OBJECTS 64
#define MAXIMUM_SUSPEND_COUNT MAXCHAR

  typedef ULONG_PTR KSPIN_LOCK;
  typedef KSPIN_LOCK *PKSPIN_LOCK;

    typedef struct DECLSPEC_ALIGN (16) _M128A {
      ULONGLONG Low;
      LONGLONG High;
    } M128A,*PM128A;

    typedef struct DECLSPEC_ALIGN (16) _XSAVE_FORMAT {
      WORD ControlWord;
      WORD StatusWord;
      BYTE TagWord;
      BYTE Reserved1;
      WORD ErrorOpcode;
      DWORD ErrorOffset;
      WORD ErrorSelector;
      WORD Reserved2;
      DWORD DataOffset;
      WORD DataSelector;
      WORD Reserved3;
      DWORD MxCsr;
      DWORD MxCsr_Mask;
      M128A FloatRegisters[8];
#ifdef _WIN64
      M128A XmmRegisters[16];
      BYTE Reserved4[96];
#else
      M128A XmmRegisters[8];
      BYTE Reserved4[220];
      DWORD Cr0NpxState;
#endif
    } XSAVE_FORMAT,*PXSAVE_FORMAT;

    typedef struct DECLSPEC_ALIGN (8) _XSAVE_AREA_HEADER {
      DWORD64 Mask;
      DWORD64 Reserved[7];
    } XSAVE_AREA_HEADER,*PXSAVE_AREA_HEADER;

    typedef struct DECLSPEC_ALIGN (16) _XSAVE_AREA {
      XSAVE_FORMAT LegacyState;
      XSAVE_AREA_HEADER Header;
    } XSAVE_AREA,*PXSAVE_AREA;

    typedef struct _XSTATE_CONTEXT {
      DWORD64 Mask;
      DWORD Length;
      DWORD Reserved1;
      PXSAVE_AREA Area;
#if defined (__i386__)
      DWORD Reserved2;
#endif
      PVOID Buffer;
#if defined (__i386__)
      DWORD Reserved3;
#endif
    } XSTATE_CONTEXT,*PXSTATE_CONTEXT;

    typedef struct _SCOPE_TABLE_AMD64 {
      DWORD Count;
      struct {
	DWORD BeginAddress;
	DWORD EndAddress;
	DWORD HandlerAddress;
	DWORD JumpTarget;
      } ScopeRecord[1];
    } SCOPE_TABLE_AMD64,*PSCOPE_TABLE_AMD64;

#ifdef _AMD64_

#if defined(__x86_64) && !defined(RC_INVOKED)

#ifdef __cplusplus
  extern "C" {
#endif

#define BitTest _bittest
#define BitTestAndComplement _bittestandcomplement
#define BitTestAndSet _bittestandset
#define BitTestAndReset _bittestandreset
#define BitTest64 _bittest64
#define BitTestAndComplement64 _bittestandcomplement64
#define BitTestAndSet64 _bittestandset64
#define BitTestAndReset64 _bittestandreset64

    /* BOOLEAN _bittest(LONG const *Base,LONG Offset);  moved to psdk_inc/intrin-impl.h */
    /* BOOLEAN _bittestandcomplement(LONG *Base,LONG Offset); moved to psdk_inc/intrin-impl.h */
    /* BOOLEAN _bittestandset(LONG *Base,LONG Offset); moved to psdk_inc/intrin-impl.h */
    /* BOOLEAN _bittestandreset(LONG *Base,LONG Offset); moved to psdk_inc/intrin-impl.h */
    /* BOOLEAN _bittest64(LONG64 const *Base,LONG64 Offset); moved to psdk_inc/intrin-impl.h */
    /* BOOLEAN _bittestandcomplement64(LONG64 *Base,LONG64 Offset); moved to psdk_inc/intrin-impl.h */
    /* BOOLEAN _bittestandset64(LONG64 *Base,LONG64 Offset); moved to psdk_inc/intrin-impl.h */
    /* BOOLEAN _bittestandreset64(LONG64 *Base,LONG64 Offset); moved to psdk_inc/intrin-impl.h */

#define BitScanForward _BitScanForward
#define BitScanReverse _BitScanReverse
#define BitScanForward64 _BitScanForward64
#define BitScanReverse64 _BitScanReverse64

    /* BOOLEAN _BitScanForward(DWORD *Index,DWORD Mask); moved to psdk_inc/intrin-impl.h */
    /* BOOLEAN _BitScanReverse(DWORD *Index,DWORD Mask); moved to psdk_inc/intrin-impl.h */
    /* BOOLEAN _BitScanForward64(DWORD *Index,DWORD64 Mask); moved to psdk_inc/intrin-impl.h */
    /* BOOLEAN _BitScanReverse64(DWORD *Index,DWORD64 Mask); moved to psdk_inc/intrin-impl.h */

#define InterlockedIncrement16 _InterlockedIncrement16
#define InterlockedDecrement16 _InterlockedDecrement16
#define InterlockedCompareExchange16 _InterlockedCompareExchange16

#define InterlockedAnd _InterlockedAnd
#define InterlockedOr _InterlockedOr
#define InterlockedXor _InterlockedXor
#define InterlockedIncrement _InterlockedIncrement
#define InterlockedIncrementAcquire InterlockedIncrement
#define InterlockedIncrementRelease InterlockedIncrement
#define InterlockedDecrement _InterlockedDecrement
#define InterlockedDecrementAcquire InterlockedDecrement
#define InterlockedDecrementRelease InterlockedDecrement
#define InterlockedAdd _InterlockedAdd
#define InterlockedExchange _InterlockedExchange
#define InterlockedExchangeAdd _InterlockedExchangeAdd
#define InterlockedCompareExchange _InterlockedCompareExchange
#define InterlockedCompareExchangeAcquire InterlockedCompareExchange
#define InterlockedCompareExchangeRelease InterlockedCompareExchange

#define InterlockedAnd64 _InterlockedAnd64
#define InterlockedAndAffinity InterlockedAnd64
#define InterlockedOr64 _InterlockedOr64
#define InterlockedOrAffinity InterlockedOr64
#define InterlockedXor64 _InterlockedXor64
#define InterlockedIncrement64 _InterlockedIncrement64
#define InterlockedDecrement64 _InterlockedDecrement64
#define InterlockedAdd64 _InterlockedAdd64
#define InterlockedExchange64 _InterlockedExchange64
#define InterlockedExchangeAcquire64 InterlockedExchange64
#define InterlockedExchangeAdd64 _InterlockedExchangeAdd64
#define InterlockedCompareExchange64 _InterlockedCompareExchange64
#define InterlockedCompareExchangeAcquire64 InterlockedCompareExchange64
#define InterlockedCompareExchangeRelease64 InterlockedCompareExchange64

#define InterlockedExchangePointer _InterlockedExchangePointer
#define InterlockedCompareExchangePointer _InterlockedCompareExchangePointer
#define InterlockedCompareExchangePointerAcquire _InterlockedCompareExchangePointer
#define InterlockedCompareExchangePointerRelease _InterlockedCompareExchangePointer

#define InterlockedExchangeAddSizeT(a,b) InterlockedExchangeAdd64((LONG64 *)a,b)
#define InterlockedIncrementSizeT(a) InterlockedIncrement64((LONG64 *)a)
#define InterlockedDecrementSizeT(a) InterlockedDecrement64((LONG64 *)a)

    /* SHORT InterlockedIncrement16(SHORT volatile *Addend); moved to psdk_inc/intrin-impl.h */
    /* SHORT InterlockedDecrement16(SHORT volatile *Addend); moved to psdk_inc/intrin-impl.h */
    /* SHORT InterlockedCompareExchange16(SHORT volatile *Destination,SHORT ExChange,SHORT Comperand); moved to psdk_inc/intrin-impl.h */
    /* LONG InterlockedIncrement(LONG volatile *Addend); moved to psdk_inc/intrin-impl.h */
    /* LONG InterlockedDecrement(LONG volatile *Addend); moved to psdk_inc/intrin-impl.h */
    /* LONG InterlockedExchange(LONG volatile *Target,LONG Value); moved to psdk_inc/intrin-impl.h */

    /* LONG InterlockedExchangeAdd(LONG volatile *Addend,LONG Value); moved to psdk_inc/intrin-impl.h */
    /* LONG InterlockedCompareExchange(LONG volatile *Destination,LONG ExChange,LONG Comperand); moved to psdk_inc/intrin-impl.h */
    /* LONG InterlockedAdd(LONG volatile *Addend,LONG Value); moved to psdk_inc/intrin-impl.h */
    /* LONG64 InterlockedIncrement64(LONG64 volatile *Addend); moved to psdk_inc/intrin-impl.h */
    /* LONG64 InterlockedDecrement64(LONG64 volatile *Addend); moved to psdk_inc/intrin-impl.h */
    /* LONG64 InterlockedExchange64(LONG64 volatile *Target,LONG64 Value); moved to psdk_inc/intrin-impl.h */
    /* LONG64 InterlockedExchangeAdd64(LONG64 volatile *Addend,LONG64 Value); moved to psdk_inc/intrin-impl.h */
    /* LONG64 InterlockedAdd64(LONG64 volatile *Addend,LONG64 Value); moved to psdk_inc/intrin-impl.h */
    /* LONG64 InterlockedCompareExchange64(LONG64 volatile *Destination,LONG64 ExChange,LONG64 Comperand); moved to psdk_inc/intrin-impl.h */
    /* PVOID InterlockedCompareExchangePointer(PVOID volatile *Destination,PVOID ExChange,PVOID Comperand); moved to psdk_inc/intrin-impl.h */
    /* PVOID InterlockedExchangePointer(PVOID volatile *Target,PVOID Value); moved to psdk_inc/intrin-impl.h */

#define CacheLineFlush(Address) _mm_clflush(Address)

# if defined(__cplusplus)
extern "C" {
# endif
# include <x86intrin.h>
# if defined(__cplusplus)
}
# endif
#include <emmintrin.h>

#define FastFence __faststorefence
#define LoadFence _mm_lfence
#define MemoryFence _mm_mfence
#define StoreFence _mm_sfence

#define YieldProcessor _mm_pause
#define MemoryBarrier _mm_mfence
#define PreFetchCacheLine(l,a) _mm_prefetch((CHAR CONST *) a,l)
#define PrefetchForWrite(p) _m_prefetchw(p)
#define ReadForWriteAccess(p) (_m_prefetchw(p),*(p))

#define PF_TEMPORAL_LEVEL_1 _MM_HINT_T0
#define PF_TEMPORAL_LEVEL_2 _MM_HINT_T1
#define PF_TEMPORAL_LEVEL_3 _MM_HINT_T2
#define PF_NON_TEMPORAL_LEVEL_ALL _MM_HINT_NTA

#define ReadMxCsr _mm_getcsr
#define WriteMxCsr _mm_setcsr

#define DbgRaiseAssertionFailure __int2c
#define GetCallersEflags() __getcallerseflags()

    unsigned __int32 __getcallerseflags(VOID);

#define GetSegmentLimit __segmentlimit

    DWORD __segmentlimit(DWORD Selector);

#define ReadTimeStampCounter() __rdtsc()

    /* VOID __movsb(PBYTE Destination,BYTE const *Source,SIZE_T Count); moved to psdk_inc/intrin-impl.h */
    /* VOID __movsw(PWORD Destination,WORD const *Source,SIZE_T Count); moved to psdk_inc/intrin-impl.h */
    /* VOID __movsd(PDWORD Destination,DWORD const *Source,SIZE_T Count); moved to psdk_inc/intrin-impl.h */
    /* VOID __movsq(PDWORD64 Destination,DWORD64 const *Source,SIZE_T Count); moved to psdk_inc/intrin-impl.h */

#define MultiplyHigh __mulh
#define UnsignedMultiplyHigh __umulh

    LONGLONG MultiplyHigh(LONGLONG Multiplier,LONGLONG Multiplicand);
    ULONGLONG UnsignedMultiplyHigh(ULONGLONG Multiplier,ULONGLONG Multiplicand);

#define ShiftLeft128 __shiftleft128
#define ShiftRight128 __shiftright128

    DWORD64 ShiftLeft128(DWORD64 LowPart,DWORD64 HighPart,BYTE Shift);
    DWORD64 ShiftRight128(DWORD64 LowPart,DWORD64 HighPart,BYTE Shift);

#define Multiply128 _mul128

    LONG64 Multiply128(LONG64 Multiplier,LONG64 Multiplicand,LONG64 *HighProduct);

#define UnsignedMultiply128 _umul128

    DWORD64 UnsignedMultiply128(DWORD64 Multiplier,DWORD64 Multiplicand,DWORD64 *HighProduct);

    LONG64 MultiplyExtract128(LONG64 Multiplier,LONG64 Multiplicand,BYTE Shift);
    DWORD64 UnsignedMultiplyExtract128(DWORD64 Multiplier,DWORD64 Multiplicand,BYTE Shift);

#ifndef __CRT__NO_INLINE
    __CRT_INLINE LONG64 MultiplyExtract128(LONG64 Multiplier,LONG64 Multiplicand,BYTE Shift) {
      LONG64 extractedProduct;
      LONG64 highProduct;
      LONG64 lowProduct;
      lowProduct = Multiply128(Multiplier,Multiplicand,&highProduct);
      extractedProduct = (LONG64)ShiftRight128((LONG64)lowProduct,(LONG64)highProduct,Shift);
      return extractedProduct;
    }

    __CRT_INLINE DWORD64 UnsignedMultiplyExtract128(DWORD64 Multiplier,DWORD64 Multiplicand,BYTE Shift) {
      DWORD64 extractedProduct;
      DWORD64 highProduct;
      DWORD64 lowProduct;
      lowProduct = UnsignedMultiply128(Multiplier,Multiplicand,&highProduct);
      extractedProduct = ShiftRight128(lowProduct,highProduct,Shift);
      return extractedProduct;
    }
#endif

    /* unsigned char __readgsbyte(unsigned __LONG32 Offset); moved to psdk_inc/intrin-impl.h */
    /* unsigned short __readgsword(unsigned __LONG32 Offset); moved to psdk_inc/intrin-impl.h */
    /* unsigned __LONG32 __readgsdword(unsigned __LONG32 Offset); moved to psdk_inc/intrin-impl.h */
    /* __MINGW_EXTENSION unsigned __int64 __readgsqword(unsigned __LONG32 Offset); moved to psdk_inc/intrin-impl.h */

    /* void __writegsbyte(unsigned __LONG32 Offset,unsigned char Data); moved to psdk_inc/intrin-impl.h */
    /* void __writegsword(unsigned __LONG32 Offset,unsigned short Data); moved to psdk_inc/intrin-impl.h */
    /* void __writegsdword(unsigned __LONG32 Offset,unsigned __LONG32 Data); moved to psdk_inc/intrin-impl.h */

#ifdef __cplusplus
  }
#endif
#endif /* defined(__x86_64) && !defined(RC_INVOKED) */

#define EXCEPTION_READ_FAULT 0
#define EXCEPTION_WRITE_FAULT 1
#define EXCEPTION_EXECUTE_FAULT 8

#if !defined(RC_INVOKED)

#define CONTEXT_AMD64 0x100000

#define CONTEXT_CONTROL (CONTEXT_AMD64 | __MSABI_LONG(0x1))
#define CONTEXT_INTEGER (CONTEXT_AMD64 | __MSABI_LONG(0x2))
#define CONTEXT_SEGMENTS (CONTEXT_AMD64 | __MSABI_LONG(0x4))
#define CONTEXT_FLOATING_POINT (CONTEXT_AMD64 | __MSABI_LONG(0x8))
#define CONTEXT_DEBUG_REGISTERS (CONTEXT_AMD64 | __MSABI_LONG(0x10))

#define CONTEXT_FULL (CONTEXT_CONTROL | CONTEXT_INTEGER | CONTEXT_FLOATING_POINT)
#define CONTEXT_ALL (CONTEXT_CONTROL | CONTEXT_INTEGER | CONTEXT_SEGMENTS | CONTEXT_FLOATING_POINT | CONTEXT_DEBUG_REGISTERS)

#define CONTEXT_EXCEPTION_ACTIVE 0x8000000
#define CONTEXT_SERVICE_ACTIVE 0x10000000
#define CONTEXT_EXCEPTION_REQUEST 0x40000000
#define CONTEXT_EXCEPTION_REPORTING 0x80000000
#endif /* !defined(RC_INVOKED) */

#define INITIAL_MXCSR 0x1f80
#define INITIAL_FPCSR 0x027f

  typedef struct _XMM_SAVE_AREA32 {
    WORD ControlWord;
    WORD StatusWord;
    BYTE TagWord;
    BYTE Reserved1;
    WORD ErrorOpcode;
    DWORD ErrorOffset;
    WORD ErrorSelector;
    WORD Reserved2;
    DWORD DataOffset;
    WORD DataSelector;
    WORD Reserved3;
    DWORD MxCsr;
    DWORD MxCsr_Mask;
    M128A FloatRegisters[8];
    M128A XmmRegisters[16];
    BYTE Reserved4[96];
  } XMM_SAVE_AREA32,*PXMM_SAVE_AREA32;

#define LEGACY_SAVE_AREA_LENGTH sizeof(XMM_SAVE_AREA32)

  typedef struct DECLSPEC_ALIGN(16) _CONTEXT {
    DWORD64 P1Home;
    DWORD64 P2Home;
    DWORD64 P3Home;
    DWORD64 P4Home;
    DWORD64 P5Home;
    DWORD64 P6Home;
    DWORD ContextFlags;
    DWORD MxCsr;
    WORD SegCs;
    WORD SegDs;
    WORD SegEs;
    WORD SegFs;
    WORD SegGs;
    WORD SegSs;
    DWORD EFlags;
    DWORD64 Dr0;
    DWORD64 Dr1;
    DWORD64 Dr2;
    DWORD64 Dr3;
    DWORD64 Dr6;
    DWORD64 Dr7;
    DWORD64 Rax;
    DWORD64 Rcx;
    DWORD64 Rdx;
    DWORD64 Rbx;
    DWORD64 Rsp;
    DWORD64 Rbp;
    DWORD64 Rsi;
    DWORD64 Rdi;
    DWORD64 R8;
    DWORD64 R9;
    DWORD64 R10;
    DWORD64 R11;
    DWORD64 R12;
    DWORD64 R13;
    DWORD64 R14;
    DWORD64 R15;
    DWORD64 Rip;
    __C89_NAMELESS union {
      XMM_SAVE_AREA32 FltSave;
      XMM_SAVE_AREA32 FloatSave;
      __C89_NAMELESS struct {
	M128A Header[2];
	M128A Legacy[8];
	M128A Xmm0;
	M128A Xmm1;
	M128A Xmm2;
	M128A Xmm3;
	M128A Xmm4;
	M128A Xmm5;
	M128A Xmm6;
	M128A Xmm7;
	M128A Xmm8;
	M128A Xmm9;
	M128A Xmm10;
	M128A Xmm11;
	M128A Xmm12;
	M128A Xmm13;
	M128A Xmm14;
	M128A Xmm15;
      };
    };
    M128A VectorRegister[26];
    DWORD64 VectorControl;
    DWORD64 DebugControl;
    DWORD64 LastBranchToRip;
    DWORD64 LastBranchFromRip;
    DWORD64 LastExceptionToRip;
    DWORD64 LastExceptionFromRip;
  } CONTEXT,*PCONTEXT;

#define RUNTIME_FUNCTION_INDIRECT 0x1

  typedef struct _RUNTIME_FUNCTION {
    DWORD BeginAddress;
    DWORD EndAddress;
    DWORD UnwindData;
  } RUNTIME_FUNCTION,*PRUNTIME_FUNCTION;

  typedef PRUNTIME_FUNCTION (*PGET_RUNTIME_FUNCTION_CALLBACK)(DWORD64 ControlPc,PVOID Context);
  typedef DWORD (*POUT_OF_PROCESS_FUNCTION_TABLE_CALLBACK)(HANDLE Process,PVOID TableAddress,PDWORD Entries,PRUNTIME_FUNCTION *Functions);

#define OUT_OF_PROCESS_FUNCTION_TABLE_CALLBACK_EXPORT_NAME "OutOfProcessFunctionTableCallback"

#define UNW_FLAG_NHANDLER   0x0
#define UNW_FLAG_EHANDLER   0x1
#define UNW_FLAG_UHANDLER   0x2
#define UNW_FLAG_CHAININFO  0x4

#endif /* end of _AMD64_ */


#ifdef _ARM_

#if defined(__arm__) && !defined(RC_INVOKED)

#ifdef __cplusplus
  extern "C" {
#endif

#define BitTest _bittest
#define BitTestAndComplement _bittestandcomplement
#define BitTestAndSet _bittestandset
#define BitTestAndReset _bittestandreset

#define BitScanForward _BitScanForward
#define BitScanReverse _BitScanReverse

#define InterlockedIncrement16 _InterlockedIncrement16
#define InterlockedDecrement16 _InterlockedDecrement16
#define InterlockedCompareExchange16 _InterlockedCompareExchange16

#define InterlockedAnd _InterlockedAnd
#define InterlockedOr _InterlockedOr
#define InterlockedXor _InterlockedXor
#define InterlockedIncrement _InterlockedIncrement
#define InterlockedIncrementAcquire InterlockedIncrement
#define InterlockedIncrementRelease InterlockedIncrement
#define InterlockedDecrement _InterlockedDecrement
#define InterlockedDecrementAcquire InterlockedDecrement
#define InterlockedDecrementRelease InterlockedDecrement
#define InterlockedAdd _InterlockedAdd
#define InterlockedExchange _InterlockedExchange
#define InterlockedExchangeAdd _InterlockedExchangeAdd
#define InterlockedCompareExchange _InterlockedCompareExchange
#define InterlockedCompareExchangeAcquire InterlockedCompareExchange
#define InterlockedCompareExchangeRelease InterlockedCompareExchange

#define InterlockedAnd64 _InterlockedAnd64
#define InterlockedAndAffinity InterlockedAnd64
#define InterlockedOr64 _InterlockedOr64
#define InterlockedOrAffinity InterlockedOr64
#define InterlockedXor64 _InterlockedXor64
#define InterlockedIncrement64 _InterlockedIncrement64
#define InterlockedDecrement64 _InterlockedDecrement64
#define InterlockedAdd64 _InterlockedAdd64
#define InterlockedExchange64 _InterlockedExchange64
#define InterlockedExchangeAcquire64 InterlockedExchange64
#define InterlockedExchangeAdd64 _InterlockedExchangeAdd64
#define InterlockedCompareExchange64 _InterlockedCompareExchange64
#define InterlockedCompareExchangeAcquire64 InterlockedCompareExchange64
#define InterlockedCompareExchangeRelease64 InterlockedCompareExchange64

#define InterlockedExchangePointer _InterlockedExchangePointer
#define InterlockedCompareExchangePointer _InterlockedCompareExchangePointer
#define InterlockedCompareExchangePointerAcquire _InterlockedCompareExchangePointer
#define InterlockedCompareExchangePointerRelease _InterlockedCompareExchangePointer

#define YieldProcessor() __asm__ __volatile__("dmb ishst\n\tyield":::"memory")
#define MemoryBarrier() __asm__ __volatile__("dmb":::"memory")

#ifdef __cplusplus
  }
#endif
#endif /* defined(__arm__) && !defined(RC_INVOKED) */

#define EXCEPTION_READ_FAULT    0
#define EXCEPTION_WRITE_FAULT   1
#define EXCEPTION_EXECUTE_FAULT 8

#if !defined(RC_INVOKED)

#define CONTEXT_ARM    0x0200000

#define CONTEXT_CONTROL         (CONTEXT_ARM | 0x00000001)
#define CONTEXT_INTEGER         (CONTEXT_ARM | 0x00000002)
#define CONTEXT_FLOATING_POINT  (CONTEXT_ARM | 0x00000004)
#define CONTEXT_DEBUG_REGISTERS (CONTEXT_ARM | 0x00000008)

#define CONTEXT_FULL (CONTEXT_CONTROL | CONTEXT_INTEGER | CONTEXT_FLOATING_POINT)

#define CONTEXT_ALL  (CONTEXT_CONTROL | CONTEXT_INTEGER | CONTEXT_FLOATING_POINT | CONTEXT_DEBUG_REGISTERS)

#define CONTEXT_EXCEPTION_ACTIVE    0x08000000
#define CONTEXT_SERVICE_ACTIVE      0x10000000
#define CONTEXT_EXCEPTION_REQUEST   0x40000000
#define CONTEXT_EXCEPTION_REPORTING 0x80000000

#define CONTEXT_UNWOUND_TO_CALL     0x20000000

#endif /* !defined(RC_INVOKED) */

#define INITIAL_CPSR  0x10
#define INITIAL_FPSCR 0x00

#define ARM_MAX_BREAKPOINTS 8
#define ARM_MAX_WATCHPOINTS 1


  typedef struct _NEON128 {
    ULONGLONG Low;
    LONGLONG High;
  } NEON128, *PNEON128;

  typedef struct DECLSPEC_ALIGN(8) _CONTEXT {
    DWORD ContextFlags;

    DWORD R0;
    DWORD R1;
    DWORD R2;
    DWORD R3;
    DWORD R4;
    DWORD R5;
    DWORD R6;
    DWORD R7;
    DWORD R8;
    DWORD R9;
    DWORD R10;
    DWORD R11;
    DWORD R12;

    DWORD Sp;
    DWORD Lr;
    DWORD Pc;
    DWORD Cpsr;

    DWORD Fpscr;
    DWORD Padding;
    union {
        NEON128   Q[16];
        ULONGLONG D[32];
        DWORD     S[32];
    } DUMMYUNIONNAME;

    DWORD Bvr[ARM_MAX_BREAKPOINTS];
    DWORD Bcr[ARM_MAX_BREAKPOINTS];
    DWORD Wvr[ARM_MAX_WATCHPOINTS];
    DWORD Wcr[ARM_MAX_WATCHPOINTS];

    DWORD Padding2[2];
  } CONTEXT, *PCONTEXT;

  typedef struct _IMAGE_ARM_RUNTIME_FUNCTION_ENTRY RUNTIME_FUNCTION, *PRUNTIME_FUNCTION;
  typedef PRUNTIME_FUNCTION (*PGET_RUNTIME_FUNCTION_CALLBACK)(DWORD ControlPc,PVOID Context);

#define UNW_FLAG_NHANDLER   0x0
#define UNW_FLAG_EHANDLER   0x1
#define UNW_FLAG_UHANDLER   0x2

#define UNWIND_HISTORY_TABLE_SIZE 12

  typedef struct _UNWIND_HISTORY_TABLE_ENTRY {
    DWORD ImageBase;
    PRUNTIME_FUNCTION FunctionEntry;
  } UNWIND_HISTORY_TABLE_ENTRY, *PUNWIND_HISTORY_TABLE_ENTRY;

  typedef struct _UNWIND_HISTORY_TABLE {
    DWORD Count;
    BYTE  LocalHint;
    BYTE  GlobalHint;
    BYTE  Search;
    BYTE  Once;
    DWORD LowAddress;
    DWORD HighAddress;
    UNWIND_HISTORY_TABLE_ENTRY Entry[UNWIND_HISTORY_TABLE_SIZE];
  } UNWIND_HISTORY_TABLE, *PUNWIND_HISTORY_TABLE;

  struct _DISPATCHER_CONTEXT;
  typedef struct _DISPATCHER_CONTEXT DISPATCHER_CONTEXT;
  typedef struct _DISPATCHER_CONTEXT *PDISPATCHER_CONTEXT;

  struct _DISPATCHER_CONTEXT {
    ULONG ControlPc;
    ULONG ImageBase;
    PRUNTIME_FUNCTION FunctionEntry;
    ULONG EstablisherFrame;
    ULONG TargetPc;
    PCONTEXT ContextRecord;
    PEXCEPTION_ROUTINE LanguageHandler;
    PVOID HandlerData;
    PUNWIND_HISTORY_TABLE HistoryTable;
    ULONG ScopeIndex;
    BOOLEAN ControlPcIsUnwound;
    PBYTE NonVolatileRegisters;
    ULONG VirtualVfpHead;
  };

  typedef struct _KNONVOLATILE_CONTEXT_POINTERS {
    PDWORD R4;
    PDWORD R5;
    PDWORD R6;
    PDWORD R7;
    PDWORD R8;
    PDWORD R9;
    PDWORD R10;
    PDWORD R11;
    PDWORD Lr;
    PULONGLONG D8;
    PULONGLONG D9;
    PULONGLONG D10;
    PULONGLONG D11;
    PULONGLONG D12;
    PULONGLONG D13;
    PULONGLONG D14;
    PULONGLONG D15;
  } KNONVOLATILE_CONTEXT_POINTERS, *PKNONVOLATILE_CONTEXT_POINTERS;

#define OUT_OF_PROCESS_FUNCTION_TABLE_CALLBACK_EXPORT_NAME "OutOfProcessFunctionTableCallback"

#endif /* _ARM_ */


#ifdef _ARM64_

#if defined(__aarch64__) && !defined(RC_INVOKED)

#ifdef __cplusplus
  extern "C" {
#endif

#define BitTest _bittest
#define BitTestAndComplement _bittestandcomplement
#define BitTestAndSet _bittestandset
#define BitTestAndReset _bittestandreset

#define BitScanForward _BitScanForward
#define BitScanReverse _BitScanReverse
#define BitScanForward64 _BitScanForward64
#define BitScanReverse64 _BitScanReverse64

#define InterlockedIncrement16 _InterlockedIncrement16
#define InterlockedDecrement16 _InterlockedDecrement16
#define InterlockedCompareExchange16 _InterlockedCompareExchange16

#define InterlockedAnd _InterlockedAnd
#define InterlockedOr _InterlockedOr
#define InterlockedXor _InterlockedXor
#define InterlockedIncrement _InterlockedIncrement
#define InterlockedIncrementAcquire InterlockedIncrement
#define InterlockedIncrementRelease InterlockedIncrement
#define InterlockedDecrement _InterlockedDecrement
#define InterlockedDecrementAcquire InterlockedDecrement
#define InterlockedDecrementRelease InterlockedDecrement
#define InterlockedAdd _InterlockedAdd
#define InterlockedExchange _InterlockedExchange
#define InterlockedExchangeAdd _InterlockedExchangeAdd
#define InterlockedCompareExchange _InterlockedCompareExchange
#define InterlockedCompareExchangeAcquire InterlockedCompareExchange
#define InterlockedCompareExchangeRelease InterlockedCompareExchange

#define InterlockedAnd64 _InterlockedAnd64
#define InterlockedAndAffinity InterlockedAnd64
#define InterlockedOr64 _InterlockedOr64
#define InterlockedOrAffinity InterlockedOr64
#define InterlockedXor64 _InterlockedXor64
#define InterlockedIncrement64 _InterlockedIncrement64
#define InterlockedDecrement64 _InterlockedDecrement64
#define InterlockedAdd64 _InterlockedAdd64
#define InterlockedExchange64 _InterlockedExchange64
#define InterlockedExchangeAcquire64 InterlockedExchange64
#define InterlockedExchangeAdd64 _InterlockedExchangeAdd64
#define InterlockedCompareExchange64 _InterlockedCompareExchange64
#define InterlockedCompareExchangeAcquire64 InterlockedCompareExchange64
#define InterlockedCompareExchangeRelease64 InterlockedCompareExchange64

#define InterlockedExchangePointer _InterlockedExchangePointer
#define InterlockedCompareExchangePointer _InterlockedCompareExchangePointer
#define InterlockedCompareExchangePointerAcquire _InterlockedCompareExchangePointer
#define InterlockedCompareExchangePointerRelease _InterlockedCompareExchangePointer

#define YieldProcessor() __asm__ __volatile__("dmb ishst\n\tyield":::"memory")
#define MemoryBarrier() __asm__ __volatile__("dmb sy":::"memory")

#ifdef __cplusplus
  }
#endif
#endif /* defined(__aarch64__) && !defined(RC_INVOKED) */

#define EXCEPTION_READ_FAULT    0
#define EXCEPTION_WRITE_FAULT   1
#define EXCEPTION_EXECUTE_FAULT 8

#if !defined(RC_INVOKED)

#define CONTEXT_ARM64           0x400000
#define CONTEXT_CONTROL         (CONTEXT_ARM64 | 0x00000001)
#define CONTEXT_INTEGER         (CONTEXT_ARM64 | 0x00000002)
#define CONTEXT_FLOATING_POINT  (CONTEXT_ARM64 | 0x00000004)
#define CONTEXT_DEBUG_REGISTERS (CONTEXT_ARM64 | 0x00000008)

#define CONTEXT_FULL (CONTEXT_CONTROL | CONTEXT_INTEGER)
#define CONTEXT_ALL  (CONTEXT_CONTROL | CONTEXT_INTEGER | CONTEXT_FLOATING_POINT | CONTEXT_DEBUG_REGISTERS)

#define EXCEPTION_READ_FAULT    0
#define EXCEPTION_WRITE_FAULT   1
#define EXCEPTION_EXECUTE_FAULT 8

#define ARM64_MAX_BREAKPOINTS   8
#define ARM64_MAX_WATCHPOINTS   2

#endif /* !defined(RC_INVOKED) */

  typedef union _NEON128 {
    struct
    {
        ULONGLONG Low;
        LONGLONG High;
    } DUMMYSTRUCTNAME;
    double D[2];
    float S[4];
    WORD  H[8];
    BYTE  B[16];
  } NEON128, *PNEON128;

  typedef struct DECLSPEC_ALIGN(16) _CONTEXT {
    ULONG ContextFlags;                 /* 000 */
    /* CONTEXT_INTEGER */
    ULONG Cpsr;                         /* 004 */
    union
    {
        struct
        {
            DWORD64 X0;                 /* 008 */
            DWORD64 X1;                 /* 010 */
            DWORD64 X2;                 /* 018 */
            DWORD64 X3;                 /* 020 */
            DWORD64 X4;                 /* 028 */
            DWORD64 X5;                 /* 030 */
            DWORD64 X6;                 /* 038 */
            DWORD64 X7;                 /* 040 */
            DWORD64 X8;                 /* 048 */
            DWORD64 X9;                 /* 050 */
            DWORD64 X10;                /* 058 */
            DWORD64 X11;                /* 060 */
            DWORD64 X12;                /* 068 */
            DWORD64 X13;                /* 070 */
            DWORD64 X14;                /* 078 */
            DWORD64 X15;                /* 080 */
            DWORD64 X16;                /* 088 */
            DWORD64 X17;                /* 090 */
            DWORD64 X18;                /* 098 */
            DWORD64 X19;                /* 0a0 */
            DWORD64 X20;                /* 0a8 */
            DWORD64 X21;                /* 0b0 */
            DWORD64 X22;                /* 0b8 */
            DWORD64 X23;                /* 0c0 */
            DWORD64 X24;                /* 0c8 */
            DWORD64 X25;                /* 0d0 */
            DWORD64 X26;                /* 0d8 */
            DWORD64 X27;                /* 0e0 */
            DWORD64 X28;                /* 0e8 */
            DWORD64 Fp;                 /* 0f0 */
            DWORD64 Lr;                 /* 0f8 */
        } DUMMYSTRUCTNAME;
        DWORD64 X[31];                  /* 008 */
    } DUMMYUNIONNAME;
    /* CONTEXT_CONTROL */
    DWORD64 Sp;                         /* 100 */
    DWORD64 Pc;                         /* 108 */
    /* CONTEXT_FLOATING_POINT */
    NEON128 V[32];                      /* 110 */
    DWORD Fpcr;                         /* 310 */
    DWORD Fpsr;                         /* 314 */
    /* CONTEXT_DEBUG_REGISTERS */
    DWORD Bcr[ARM64_MAX_BREAKPOINTS];   /* 318 */
    DWORD64 Bvr[ARM64_MAX_BREAKPOINTS]; /* 338 */
    DWORD Wcr[ARM64_MAX_WATCHPOINTS];   /* 378 */
    DWORD64 Wvr[ARM64_MAX_WATCHPOINTS]; /* 380 */
  } CONTEXT, *PCONTEXT;

  typedef struct _IMAGE_ARM64_RUNTIME_FUNCTION_ENTRY RUNTIME_FUNCTION, *PRUNTIME_FUNCTION;
  typedef PRUNTIME_FUNCTION (*PGET_RUNTIME_FUNCTION_CALLBACK)(DWORD64 ControlPc,PVOID Context);

#define UNW_FLAG_NHANDLER   0x0
#define UNW_FLAG_EHANDLER   0x1
#define UNW_FLAG_UHANDLER   0x2

#define UNWIND_HISTORY_TABLE_SIZE 12

  typedef struct _UNWIND_HISTORY_TABLE_ENTRY {
    DWORD64 ImageBase;
    PRUNTIME_FUNCTION FunctionEntry;
  } UNWIND_HISTORY_TABLE_ENTRY, *PUNWIND_HISTORY_TABLE_ENTRY;

  typedef struct _UNWIND_HISTORY_TABLE {
    DWORD   Count;
    BYTE    LocalHint;
    BYTE    GlobalHint;
    BYTE    Search;
    BYTE    Once;
    DWORD64 LowAddress;
    DWORD64 HighAddress;
    UNWIND_HISTORY_TABLE_ENTRY Entry[UNWIND_HISTORY_TABLE_SIZE];
  } UNWIND_HISTORY_TABLE, *PUNWIND_HISTORY_TABLE;

  struct _DISPATCHER_CONTEXT;
  typedef struct _DISPATCHER_CONTEXT DISPATCHER_CONTEXT;
  typedef struct _DISPATCHER_CONTEXT *PDISPATCHER_CONTEXT;

  struct _DISPATCHER_CONTEXT {
    ULONG_PTR ControlPc;
    ULONG_PTR ImageBase;
    PRUNTIME_FUNCTION FunctionEntry;
    ULONG_PTR EstablisherFrame;
    ULONG_PTR TargetPc;
    PCONTEXT ContextRecord;
    PEXCEPTION_ROUTINE LanguageHandler;
    PVOID HandlerData;
    PUNWIND_HISTORY_TABLE HistoryTable;
    ULONG ScopeIndex;
    BOOLEAN ControlPcIsUnwound;
    PBYTE NonVolatileRegisters;
  };

  typedef struct _KNONVOLATILE_CONTEXT_POINTERS {
    PDWORD64 X19;
    PDWORD64 X20;
    PDWORD64 X21;
    PDWORD64 X22;
    PDWORD64 X23;
    PDWORD64 X24;
    PDWORD64 X25;
    PDWORD64 X26;
    PDWORD64 X27;
    PDWORD64 X28;
    PDWORD64 Fp;
    PDWORD64 Lr;

    PDWORD64 D8;
    PDWORD64 D9;
    PDWORD64 D10;
    PDWORD64 D11;
    PDWORD64 D12;
    PDWORD64 D13;
    PDWORD64 D14;
    PDWORD64 D15;
  } KNONVOLATILE_CONTEXT_POINTERS, *PKNONVOLATILE_CONTEXT_POINTERS;

#define OUT_OF_PROCESS_FUNCTION_TABLE_CALLBACK_EXPORT_NAME "OutOfProcessFunctionTableCallback"

#endif /* _ARM64_ */


#ifdef _X86_

#if defined(__i386__) && !defined(__x86_64) && !defined(RC_INVOKED)
#ifdef __cplusplus
  extern "C" {
#endif

#define BitTest _bittest
#define BitTestAndComplement _bittestandcomplement
#define BitTestAndSet _bittestandset
#define BitTestAndReset _bittestandreset

#define BitScanForward _BitScanForward
#define BitScanReverse _BitScanReverse

#define InterlockedIncrement16 _InterlockedIncrement16
#define InterlockedDecrement16 _InterlockedDecrement16
#define InterlockedCompareExchange16 _InterlockedCompareExchange16

#define InterlockedAnd _InterlockedAnd
#define InterlockedOr _InterlockedOr
#define InterlockedXor _InterlockedXor
#define InterlockedIncrement _InterlockedIncrement
#define InterlockedIncrementAcquire InterlockedIncrement
#define InterlockedIncrementRelease InterlockedIncrement
#define InterlockedDecrement _InterlockedDecrement
#define InterlockedDecrementAcquire InterlockedDecrement
#define InterlockedDecrementRelease InterlockedDecrement
#define InterlockedAdd _InterlockedAdd
#define InterlockedExchange _InterlockedExchange
#define InterlockedExchangeAdd _InterlockedExchangeAdd
#define InterlockedCompareExchange _InterlockedCompareExchange
#define InterlockedCompareExchangeAcquire InterlockedCompareExchange
#define InterlockedCompareExchangeRelease InterlockedCompareExchange

#define InterlockedAnd64 _InterlockedAnd64
#define InterlockedAndAffinity InterlockedAnd64
#define InterlockedOr64 _InterlockedOr64
#define InterlockedOrAffinity InterlockedOr64
#define InterlockedXor64 _InterlockedXor64
#define InterlockedIncrement64 _InterlockedIncrement64
#define InterlockedDecrement64 _InterlockedDecrement64
#define InterlockedAdd64 _InterlockedAdd64
#define InterlockedExchange64 _InterlockedExchange64
#define InterlockedExchangeAcquire64 InterlockedExchange64
#define InterlockedExchangeAdd64 _InterlockedExchangeAdd64
#define InterlockedCompareExchange64 _InterlockedCompareExchange64
#define InterlockedCompareExchangeAcquire64 InterlockedCompareExchange64
#define InterlockedCompareExchangeRelease64 InterlockedCompareExchange64

#define InterlockedExchangePointer _InterlockedExchangePointer
#define InterlockedCompareExchangePointer(Destination, ExChange, Comperand) (PVOID) (LONG_PTR)InterlockedCompareExchange ((LONG volatile *) (Destination),(LONG) (LONG_PTR) (ExChange),(LONG) (LONG_PTR) (Comperand))
#define InterlockedCompareExchangePointerAcquire InterlockedCompareExchangePointer
#define InterlockedCompareExchangePointerRelease InterlockedCompareExchangePointer

#ifdef _PREFIX_
    /* BYTE __readfsbyte(DWORD Offset); moved to psdk_inc/intrin-impl.h */
    /* WORD __readfsword(DWORD Offset); moved to psdk_inc/intrin-impl.h */
    /* DWORD __readfsdword(DWORD Offset); moved to psdk_inc/intrin-impl.h */
    /* VOID __writefsbyte(DWORD Offset,BYTE Data); moved to psdk_inc/intrin-impl.h */
    /* VOID __writefsword(DWORD Offset,WORD Data); moved to psdk_inc/intrin-impl.h */
    /* VOID __writefsdword(DWORD Offset,DWORD Data); moved to psdk_inc/intrin-impl.h */
#endif

#ifdef __cplusplus
  }
#endif
#endif /* defined(__i386__) && !defined(__x86_64) && !defined(RC_INVOKED) */

#if defined(__i386__) && !defined(__x86_64)

#ifdef __SSE2__
#include <emmintrin.h>
#define YieldProcessor _mm_pause
#define MemoryBarrier _mm_mfence
#else
#define YieldProcessor __buildpause
VOID MemoryBarrier(VOID);
FORCEINLINE VOID MemoryBarrier(VOID)
__buildmemorybarrier()
#endif

#define PreFetchCacheLine(l,a)
#define ReadForWriteAccess(p) (*(p))

#define PF_TEMPORAL_LEVEL_1
#define PF_NON_TEMPORAL_LEVEL_ALL

#define PcTeb 0x18
  struct _TEB *NtCurrentTeb(void);
  PVOID GetCurrentFiber(void);
  PVOID GetFiberData(void);

#define DbgRaiseAssertionFailure __int2c

  FORCEINLINE struct _TEB *NtCurrentTeb(void)
  {
    return (struct _TEB *)__readfsdword(PcTeb);
  }
  FORCEINLINE PVOID GetCurrentFiber(void)
  {
    return(PVOID)__readfsdword(0x10);
  }
  FORCEINLINE PVOID GetFiberData(void)
  {
      return *(PVOID *)GetCurrentFiber();
  }
#endif /* defined(__i386__) && !defined(__x86_64) */

#define EXCEPTION_READ_FAULT 0
#define EXCEPTION_WRITE_FAULT 1
#define EXCEPTION_EXECUTE_FAULT 8

#define SIZE_OF_80387_REGISTERS 80

#if !defined(RC_INVOKED)

#define CONTEXT_i386 0x00010000
#define CONTEXT_i486 0x00010000

#define CONTEXT_CONTROL (CONTEXT_i386 | __MSABI_LONG(0x00000001))
#define CONTEXT_INTEGER (CONTEXT_i386 | __MSABI_LONG(0x00000002))
#define CONTEXT_SEGMENTS (CONTEXT_i386 | __MSABI_LONG(0x00000004))
#define CONTEXT_FLOATING_POINT (CONTEXT_i386 | __MSABI_LONG(0x00000008))
#define CONTEXT_DEBUG_REGISTERS (CONTEXT_i386 | __MSABI_LONG(0x00000010))
#define CONTEXT_EXTENDED_REGISTERS (CONTEXT_i386 | __MSABI_LONG(0x00000020))

#define CONTEXT_FULL (CONTEXT_CONTROL | CONTEXT_INTEGER | CONTEXT_SEGMENTS)

#define CONTEXT_ALL (CONTEXT_CONTROL | CONTEXT_INTEGER | CONTEXT_SEGMENTS | CONTEXT_FLOATING_POINT | CONTEXT_DEBUG_REGISTERS | CONTEXT_EXTENDED_REGISTERS)
#endif /* !defined(RC_INVOKED) */

#define MAXIMUM_SUPPORTED_EXTENSION 512

    typedef struct _FLOATING_SAVE_AREA {
      DWORD ControlWord;
      DWORD StatusWord;
      DWORD TagWord;
      DWORD ErrorOffset;
      DWORD ErrorSelector;
      DWORD DataOffset;
      DWORD DataSelector;
      BYTE RegisterArea[SIZE_OF_80387_REGISTERS];
      DWORD Cr0NpxState;
    } FLOATING_SAVE_AREA;

    typedef FLOATING_SAVE_AREA *PFLOATING_SAVE_AREA;

    typedef struct _CONTEXT {
      DWORD ContextFlags;
      DWORD Dr0;
      DWORD Dr1;
      DWORD Dr2;
      DWORD Dr3;
      DWORD Dr6;
      DWORD Dr7;
      FLOATING_SAVE_AREA FloatSave;
      DWORD SegGs;
      DWORD SegFs;
      DWORD SegEs;
      DWORD SegDs;

      DWORD Edi;
      DWORD Esi;
      DWORD Ebx;
      DWORD Edx;
      DWORD Ecx;
      DWORD Eax;
      DWORD Ebp;
      DWORD Eip;
      DWORD SegCs;
      DWORD EFlags;
      DWORD Esp;
      DWORD SegSs;
      BYTE ExtendedRegisters[MAXIMUM_SUPPORTED_EXTENSION];
    } CONTEXT;

    typedef CONTEXT *PCONTEXT;

#endif /* end of _X86_ */

  /* LONG WINAPI InterlockedIncrement(LONG volatile *); moved to psdk_inc/intrin-impl.h */
  /* LONG WINAPI InterlockedDecrement(LONG volatile *); moved to psdk_inc/intrin-impl.h */
  /* LONG WINAPI InterlockedExchange(LONG volatile *, LONG); moved to psdk_inc/intrin-impl.h */

#ifndef _LDT_ENTRY_DEFINED
#define _LDT_ENTRY_DEFINED

    typedef struct _LDT_ENTRY {
      WORD LimitLow;
      WORD BaseLow;
      union {
	struct {
	  BYTE BaseMid;
	  BYTE Flags1;
	  BYTE Flags2;
	  BYTE BaseHi;
	} Bytes;
	struct {
	  DWORD BaseMid : 8;
	  DWORD Type : 5;
	  DWORD Dpl : 2;
	  DWORD Pres : 1;
	  DWORD LimitHi : 4;
	  DWORD Sys : 1;
	  DWORD Reserved_0 : 1;
	  DWORD Default_Big : 1;
	  DWORD Granularity : 1;
	  DWORD BaseHi : 8;
	} Bits;
      } HighWord;
    } LDT_ENTRY,*PLDT_ENTRY;
#endif /* _LDT_ENTRY_DEFINED */

#if defined(__ia64__) && !defined(RC_INVOKED)

#ifdef __cplusplus
    extern "C" {
#endif

      BOOLEAN BitScanForward64(DWORD *Index,DWORD64 Mask);
      BOOLEAN BitScanReverse64(DWORD *Index,DWORD64 Mask);

#ifdef __cplusplus
    }
#endif
#endif /* defined(__ia64__) && !defined(RC_INVOKED) */

#if !defined(GENUTIL) && !defined(_GENIA64_) && defined(_IA64_)

    void *_cdecl _rdteb(void);

#ifdef __ia64__
#define NtCurrentTeb() ((struct _TEB *)_rdteb())
#define GetCurrentFiber() (((PNT_TIB)NtCurrentTeb())->FiberData)
#define GetFiberData() (*(PVOID *)(GetCurrentFiber()))

#ifdef __cplusplus
    extern "C" {
#endif

      void __break(int);
      void __yield(void);
      void __mf(void);
      void __lfetch(int Level,VOID CONST *Address);
      void __lfetchfault(int Level,VOID CONST *Address);
      void __lfetch_excl(int Level,VOID CONST *Address);
      void __lfetchfault_excl(int Level,VOID CONST *Address);

#define MD_LFHINT_NONE 0x00
#define MD_LFHINT_NT1 0x01
#define MD_LFHINT_NT2 0x02
#define MD_LFHINT_NTA 0x03

#ifdef __cplusplus
    }
#endif

#define YieldProcessor __yield
#define MemoryBarrier __mf
#define PreFetchCacheLine __lfetch
#define ReadForWriteAccess(p) (*(p))
#define DbgRaiseAssertionFailure() __break(ASSERT_BREAKPOINT)

#define PF_TEMPORAL_LEVEL_1 MD_LFHINT_NONE
#define PF_NON_TEMPORAL_LEVEL_ALL MD_LFHINT_NTA

#define UnsignedMultiplyHigh __UMULH

    ULONGLONG UnsignedMultiplyHigh(ULONGLONG Multiplier,ULONGLONG Multiplicand);
#else  /* __ia64__ */
    struct _TEB *NtCurrentTeb(void);
#endif /* __ia64__ */
#endif /* !defined(GENUTIL) && !defined(_GENIA64_) && defined(_IA64_) */

#ifdef _IA64_

#define EXCEPTION_READ_FAULT 0
#define EXCEPTION_WRITE_FAULT 1
#define EXCEPTION_EXECUTE_FAULT 2

#if !defined(RC_INVOKED)

#define CONTEXT_IA64 0x00080000

#define CONTEXT_CONTROL (CONTEXT_IA64 | __MSABI_LONG(0x00000001))
#define CONTEXT_LOWER_FLOATING_POINT (CONTEXT_IA64 | __MSABI_LONG(0x00000002))
#define CONTEXT_HIGHER_FLOATING_POINT (CONTEXT_IA64 | __MSABI_LONG(0x00000004))
#define CONTEXT_INTEGER (CONTEXT_IA64 | __MSABI_LONG(0x00000008))
#define CONTEXT_DEBUG (CONTEXT_IA64 | __MSABI_LONG(0x00000010))
#define CONTEXT_IA32_CONTROL (CONTEXT_IA64 | __MSABI_LONG(0x00000020))

#define CONTEXT_FLOATING_POINT (CONTEXT_LOWER_FLOATING_POINT | CONTEXT_HIGHER_FLOATING_POINT)
#define CONTEXT_FULL (CONTEXT_CONTROL | CONTEXT_FLOATING_POINT | CONTEXT_INTEGER | CONTEXT_IA32_CONTROL)
#define CONTEXT_ALL (CONTEXT_CONTROL | CONTEXT_FLOATING_POINT | CONTEXT_INTEGER | CONTEXT_DEBUG | CONTEXT_IA32_CONTROL)

#define CONTEXT_EXCEPTION_ACTIVE 0x8000000
#define CONTEXT_SERVICE_ACTIVE 0x10000000
#define CONTEXT_EXCEPTION_REQUEST 0x40000000
#define CONTEXT_EXCEPTION_REPORTING 0x80000000
#endif /* !defined(RC_INVOKED) */

    typedef struct _CONTEXT {
      DWORD ContextFlags;
      DWORD Fill1[3];
      ULONGLONG DbI0;
      ULONGLONG DbI1;
      ULONGLONG DbI2;
      ULONGLONG DbI3;
      ULONGLONG DbI4;
      ULONGLONG DbI5;
      ULONGLONG DbI6;
      ULONGLONG DbI7;
      ULONGLONG DbD0;
      ULONGLONG DbD1;
      ULONGLONG DbD2;
      ULONGLONG DbD3;
      ULONGLONG DbD4;
      ULONGLONG DbD5;
      ULONGLONG DbD6;
      ULONGLONG DbD7;
      FLOAT128 FltS0;
      FLOAT128 FltS1;
      FLOAT128 FltS2;
      FLOAT128 FltS3;
      FLOAT128 FltT0;
      FLOAT128 FltT1;
      FLOAT128 FltT2;
      FLOAT128 FltT3;
      FLOAT128 FltT4;
      FLOAT128 FltT5;
      FLOAT128 FltT6;
      FLOAT128 FltT7;
      FLOAT128 FltT8;
      FLOAT128 FltT9;
      FLOAT128 FltS4;
      FLOAT128 FltS5;
      FLOAT128 FltS6;
      FLOAT128 FltS7;
      FLOAT128 FltS8;
      FLOAT128 FltS9;
      FLOAT128 FltS10;
      FLOAT128 FltS11;
      FLOAT128 FltS12;
      FLOAT128 FltS13;
      FLOAT128 FltS14;
      FLOAT128 FltS15;
      FLOAT128 FltS16;
      FLOAT128 FltS17;
      FLOAT128 FltS18;
      FLOAT128 FltS19;
      FLOAT128 FltF32;
      FLOAT128 FltF33;
      FLOAT128 FltF34;
      FLOAT128 FltF35;
      FLOAT128 FltF36;
      FLOAT128 FltF37;
      FLOAT128 FltF38;
      FLOAT128 FltF39;
      FLOAT128 FltF40;
      FLOAT128 FltF41;
      FLOAT128 FltF42;
      FLOAT128 FltF43;
      FLOAT128 FltF44;
      FLOAT128 FltF45;
      FLOAT128 FltF46;
      FLOAT128 FltF47;
      FLOAT128 FltF48;
      FLOAT128 FltF49;
      FLOAT128 FltF50;
      FLOAT128 FltF51;
      FLOAT128 FltF52;
      FLOAT128 FltF53;
      FLOAT128 FltF54;
      FLOAT128 FltF55;
      FLOAT128 FltF56;
      FLOAT128 FltF57;
      FLOAT128 FltF58;
      FLOAT128 FltF59;
      FLOAT128 FltF60;
      FLOAT128 FltF61;
      FLOAT128 FltF62;
      FLOAT128 FltF63;
      FLOAT128 FltF64;
      FLOAT128 FltF65;
      FLOAT128 FltF66;
      FLOAT128 FltF67;
      FLOAT128 FltF68;
      FLOAT128 FltF69;
      FLOAT128 FltF70;
      FLOAT128 FltF71;
      FLOAT128 FltF72;
      FLOAT128 FltF73;
      FLOAT128 FltF74;
      FLOAT128 FltF75;
      FLOAT128 FltF76;
      FLOAT128 FltF77;
      FLOAT128 FltF78;
      FLOAT128 FltF79;
      FLOAT128 FltF80;
      FLOAT128 FltF81;
      FLOAT128 FltF82;
      FLOAT128 FltF83;
      FLOAT128 FltF84;
      FLOAT128 FltF85;
      FLOAT128 FltF86;
      FLOAT128 FltF87;
      FLOAT128 FltF88;
      FLOAT128 FltF89;
      FLOAT128 FltF90;
      FLOAT128 FltF91;
      FLOAT128 FltF92;
      FLOAT128 FltF93;
      FLOAT128 FltF94;
      FLOAT128 FltF95;
      FLOAT128 FltF96;
      FLOAT128 FltF97;
      FLOAT128 FltF98;
      FLOAT128 FltF99;
      FLOAT128 FltF100;
      FLOAT128 FltF101;
      FLOAT128 FltF102;
      FLOAT128 FltF103;
      FLOAT128 FltF104;
      FLOAT128 FltF105;
      FLOAT128 FltF106;
      FLOAT128 FltF107;
      FLOAT128 FltF108;
      FLOAT128 FltF109;
      FLOAT128 FltF110;
      FLOAT128 FltF111;
      FLOAT128 FltF112;
      FLOAT128 FltF113;
      FLOAT128 FltF114;
      FLOAT128 FltF115;
      FLOAT128 FltF116;
      FLOAT128 FltF117;
      FLOAT128 FltF118;
      FLOAT128 FltF119;
      FLOAT128 FltF120;
      FLOAT128 FltF121;
      FLOAT128 FltF122;
      FLOAT128 FltF123;
      FLOAT128 FltF124;
      FLOAT128 FltF125;
      FLOAT128 FltF126;
      FLOAT128 FltF127;
      ULONGLONG StFPSR;
      ULONGLONG IntGp;
      ULONGLONG IntT0;
      ULONGLONG IntT1;
      ULONGLONG IntS0;
      ULONGLONG IntS1;
      ULONGLONG IntS2;
      ULONGLONG IntS3;
      ULONGLONG IntV0;
      ULONGLONG IntT2;
      ULONGLONG IntT3;
      ULONGLONG IntT4;
      ULONGLONG IntSp;
      ULONGLONG IntTeb;
      ULONGLONG IntT5;
      ULONGLONG IntT6;
      ULONGLONG IntT7;
      ULONGLONG IntT8;
      ULONGLONG IntT9;
      ULONGLONG IntT10;
      ULONGLONG IntT11;
      ULONGLONG IntT12;
      ULONGLONG IntT13;
      ULONGLONG IntT14;
      ULONGLONG IntT15;
      ULONGLONG IntT16;
      ULONGLONG IntT17;
      ULONGLONG IntT18;
      ULONGLONG IntT19;
      ULONGLONG IntT20;
      ULONGLONG IntT21;
      ULONGLONG IntT22;
      ULONGLONG IntNats;
      ULONGLONG Preds;
      ULONGLONG BrRp;
      ULONGLONG BrS0;
      ULONGLONG BrS1;
      ULONGLONG BrS2;
      ULONGLONG BrS3;
      ULONGLONG BrS4;
      ULONGLONG BrT0;
      ULONGLONG BrT1;
      ULONGLONG ApUNAT;
      ULONGLONG ApLC;
      ULONGLONG ApEC;
      ULONGLONG ApCCV;
      ULONGLONG ApDCR;
      ULONGLONG RsPFS;
      ULONGLONG RsBSP;
      ULONGLONG RsBSPSTORE;
      ULONGLONG RsRSC;
      ULONGLONG RsRNAT;
      ULONGLONG StIPSR;
      ULONGLONG StIIP;
      ULONGLONG StIFS;
      ULONGLONG StFCR;
      ULONGLONG Eflag;
      ULONGLONG SegCSD;
      ULONGLONG SegSSD;
      ULONGLONG Cflag;
      ULONGLONG StFSR;
      ULONGLONG StFIR;
      ULONGLONG StFDR;
      ULONGLONG UNUSEDPACK;
    } CONTEXT,*PCONTEXT;

    typedef struct _PLABEL_DESCRIPTOR {
      ULONGLONG EntryPoint;
      ULONGLONG GlobalPointer;
    } PLABEL_DESCRIPTOR,*PPLABEL_DESCRIPTOR;

    typedef struct _RUNTIME_FUNCTION {
      DWORD BeginAddress;
      DWORD EndAddress;
      DWORD UnwindInfoAddress;
    } RUNTIME_FUNCTION,*PRUNTIME_FUNCTION;

    typedef PRUNTIME_FUNCTION (*PGET_RUNTIME_FUNCTION_CALLBACK)(DWORD64 ControlPc,PVOID Context);
    typedef DWORD (*POUT_OF_PROCESS_FUNCTION_TABLE_CALLBACK)(HANDLE Process,PVOID TableAddress,PDWORD Entries,PRUNTIME_FUNCTION *Functions);

#define OUT_OF_PROCESS_FUNCTION_TABLE_CALLBACK_EXPORT_NAME "OutOfProcessFunctionTableCallback"

    VOID __jump_unwind(ULONGLONG TargetMsFrame,ULONGLONG TargetBsFrame,ULONGLONG TargetPc);
#endif /* end of _IA64_ */

/* http://www.nynaeve.net/?p=99 */

#define EXCEPTION_NONCONTINUABLE 0x1
#define EXCEPTION_UNWINDING	   0x2
#define EXCEPTION_EXIT_UNWIND      0x4
#define EXCEPTION_STACK_INVALID    0x8
#define EXCEPTION_NESTED_CALL      0x10
#define EXCEPTION_TARGET_UNWIND    0x20
#define EXCEPTION_COLLIDED_UNWIND  0x40
#define EXCEPTION_UNWIND           0x66

#define IS_UNWINDING(f) ((f & EXCEPTION_UNWIND) != 0)
#define IS_DISPATCHING(f) ((f & EXCEPTION_UNWIND) == 0)
#define IS_TARGET_UNWIND(f) ((f & EXCEPTION_TARGET_UNWIND) != 0)

#define EXCEPTION_MAXIMUM_PARAMETERS 15

    typedef struct _EXCEPTION_RECORD {
      DWORD ExceptionCode;
      DWORD ExceptionFlags;
      struct _EXCEPTION_RECORD *ExceptionRecord;
      PVOID ExceptionAddress;
      DWORD NumberParameters;
      ULONG_PTR ExceptionInformation[EXCEPTION_MAXIMUM_PARAMETERS];
    } EXCEPTION_RECORD;

    typedef EXCEPTION_RECORD *PEXCEPTION_RECORD;

    typedef struct _EXCEPTION_RECORD32 {
      DWORD ExceptionCode;
      DWORD ExceptionFlags;
      DWORD ExceptionRecord;
      DWORD ExceptionAddress;
      DWORD NumberParameters;
      DWORD ExceptionInformation[EXCEPTION_MAXIMUM_PARAMETERS];
    } EXCEPTION_RECORD32,*PEXCEPTION_RECORD32;

    typedef struct _EXCEPTION_RECORD64 {
      DWORD ExceptionCode;
      DWORD ExceptionFlags;
      DWORD64 ExceptionRecord;
      DWORD64 ExceptionAddress;
      DWORD NumberParameters;
      DWORD __unusedAlignment;
      DWORD64 ExceptionInformation[EXCEPTION_MAXIMUM_PARAMETERS];
    } EXCEPTION_RECORD64,*PEXCEPTION_RECORD64;

    typedef struct _EXCEPTION_POINTERS {
      PEXCEPTION_RECORD ExceptionRecord;
      PCONTEXT ContextRecord;
    } EXCEPTION_POINTERS,*PEXCEPTION_POINTERS;

#ifdef __ia64__
    NTSYSAPI VOID NTAPI RtlUnwind2 (FRAME_POINTERS TargetFrame, PVOID TargetIp, PEXCEPTION_RECORD ExceptionRecord, PVOID ReturnValue, PCONTEXT ContextRecord);
#endif

#ifdef __x86_64__

    /* http://msdn.microsoft.com/en-us/library/ms680597(VS.85).aspx */

#define UNWIND_HISTORY_TABLE_SIZE 12

  typedef struct _UNWIND_HISTORY_TABLE_ENTRY {
    ULONG64 ImageBase;
    PRUNTIME_FUNCTION FunctionEntry;
  } UNWIND_HISTORY_TABLE_ENTRY, *PUNWIND_HISTORY_TABLE_ENTRY;

#define UNWIND_HISTORY_TABLE_NONE    0
#define UNWIND_HISTORY_TABLE_GLOBAL  1
#define UNWIND_HISTORY_TABLE_LOCAL   2

  typedef struct _UNWIND_HISTORY_TABLE {
    ULONG Count;
    BYTE  LocalHint;
    BYTE  GlobalHint;
    BYTE  Search;
    BYTE  Once;
    ULONG64 LowAddress;
    ULONG64 HighAddress;
    UNWIND_HISTORY_TABLE_ENTRY Entry[UNWIND_HISTORY_TABLE_SIZE];
  } UNWIND_HISTORY_TABLE, *PUNWIND_HISTORY_TABLE;

  /* http://msdn.microsoft.com/en-us/library/b6sf5kbd(VS.80).aspx */

  struct _DISPATCHER_CONTEXT;
  typedef struct _DISPATCHER_CONTEXT DISPATCHER_CONTEXT;
  typedef struct _DISPATCHER_CONTEXT *PDISPATCHER_CONTEXT;

  struct _DISPATCHER_CONTEXT {
    ULONG64 ControlPc;
    ULONG64 ImageBase;
    PRUNTIME_FUNCTION FunctionEntry;
    ULONG64 EstablisherFrame;
    ULONG64 TargetIp;
    PCONTEXT ContextRecord;
    PEXCEPTION_ROUTINE LanguageHandler;
    PVOID HandlerData;
    /* http://www.nynaeve.net/?p=99 */
    PUNWIND_HISTORY_TABLE HistoryTable;
    ULONG ScopeIndex;
    ULONG Fill0;
  };

  /* http://msdn.microsoft.com/en-us/library/ms680617(VS.85).aspx */

  typedef struct _KNONVOLATILE_CONTEXT_POINTERS
  {
    PM128A FloatingContext[16];
    PULONG64 IntegerContext[16];
  } KNONVOLATILE_CONTEXT_POINTERS, *PKNONVOLATILE_CONTEXT_POINTERS;
#endif /* defined(__x86_64__) */

    typedef PVOID PACCESS_TOKEN;
    typedef PVOID PSECURITY_DESCRIPTOR;
    typedef PVOID PSID;
    typedef PVOID PCLAIMS_BLOB;
    typedef DWORD ACCESS_MASK;
    typedef ACCESS_MASK *PACCESS_MASK;

#define DELETE (__MSABI_LONG(0x00010000))
#define READ_CONTROL (__MSABI_LONG(0x00020000))
#define WRITE_DAC (__MSABI_LONG(0x00040000))
#define WRITE_OWNER (__MSABI_LONG(0x00080000))
#define SYNCHRONIZE (__MSABI_LONG(0x00100000))

#define STANDARD_RIGHTS_REQUIRED (__MSABI_LONG(0x000F0000))

#define STANDARD_RIGHTS_READ (READ_CONTROL)
#define STANDARD_RIGHTS_WRITE (READ_CONTROL)
#define STANDARD_RIGHTS_EXECUTE (READ_CONTROL)

#define STANDARD_RIGHTS_ALL (__MSABI_LONG(0x001F0000))

#define SPECIFIC_RIGHTS_ALL (__MSABI_LONG(0x0000FFFF))

#define ACCESS_SYSTEM_SECURITY (__MSABI_LONG(0x01000000))
#define MAXIMUM_ALLOWED (__MSABI_LONG(0x02000000))

#define GENERIC_READ (__MSABI_LONG(0x80000000))
#define GENERIC_WRITE (__MSABI_LONG(0x40000000))
#define GENERIC_EXECUTE (__MSABI_LONG(0x20000000))
#define GENERIC_ALL (__MSABI_LONG(0x10000000))

    typedef struct _GENERIC_MAPPING {
      ACCESS_MASK GenericRead;
      ACCESS_MASK GenericWrite;
      ACCESS_MASK GenericExecute;
      ACCESS_MASK GenericAll;
    } GENERIC_MAPPING;
    typedef GENERIC_MAPPING *PGENERIC_MAPPING;

#include <pshpack4.h>
    typedef struct _LUID_AND_ATTRIBUTES {
      LUID Luid;
      DWORD Attributes;
    } LUID_AND_ATTRIBUTES,*PLUID_AND_ATTRIBUTES;
    typedef LUID_AND_ATTRIBUTES LUID_AND_ATTRIBUTES_ARRAY[ANYSIZE_ARRAY];
    typedef LUID_AND_ATTRIBUTES_ARRAY *PLUID_AND_ATTRIBUTES_ARRAY;
#include <poppack.h>

#ifndef SID_IDENTIFIER_AUTHORITY_DEFINED
#define SID_IDENTIFIER_AUTHORITY_DEFINED
    typedef struct _SID_IDENTIFIER_AUTHORITY {
      BYTE Value[6];
    } SID_IDENTIFIER_AUTHORITY,*PSID_IDENTIFIER_AUTHORITY;
#endif /* SID_IDENTIFIER_AUTHORITY_DEFINED */

#ifndef SID_DEFINED
#define SID_DEFINED
    typedef struct _SID {
      BYTE Revision;
      BYTE SubAuthorityCount;
      SID_IDENTIFIER_AUTHORITY IdentifierAuthority;
      DWORD SubAuthority[ANYSIZE_ARRAY];
    } SID,*PISID;
#endif /* SID_DEFINED */

#define SID_REVISION (1)
#define SID_MAX_SUB_AUTHORITIES (15)
#define SID_RECOMMENDED_SUB_AUTHORITIES (1)
#ifndef __WIDL__
#define SECURITY_MAX_SID_SIZE (sizeof (SID) - sizeof (DWORD) + (SID_MAX_SUB_AUTHORITIES *sizeof (DWORD)))
#endif

#define SID_HASH_SIZE 32

    typedef enum _SID_NAME_USE {
      SidTypeUser = 1,SidTypeGroup,SidTypeDomain,SidTypeAlias,SidTypeWellKnownGroup,SidTypeDeletedAccount,SidTypeInvalid,SidTypeUnknown,SidTypeComputer,SidTypeLabel,SidTypeLogonSession
    } SID_NAME_USE,*PSID_NAME_USE;

    typedef struct _SID_AND_ATTRIBUTES {
#ifdef __WIDL__
      PISID Sid;
#else
      PSID Sid;
#endif
      DWORD Attributes;
    } SID_AND_ATTRIBUTES,*PSID_AND_ATTRIBUTES;

    typedef SID_AND_ATTRIBUTES SID_AND_ATTRIBUTES_ARRAY[ANYSIZE_ARRAY];
    typedef SID_AND_ATTRIBUTES_ARRAY *PSID_AND_ATTRIBUTES_ARRAY;

    typedef ULONG_PTR SID_HASH_ENTRY, *PSID_HASH_ENTRY;

    typedef struct _SID_AND_ATTRIBUTES_HASH {
      DWORD SidCount;
      PSID_AND_ATTRIBUTES SidAttr;
      SID_HASH_ENTRY Hash[SID_HASH_SIZE];
    } SID_AND_ATTRIBUTES_HASH, *PSID_AND_ATTRIBUTES_HASH;

#define SECURITY_NULL_SID_AUTHORITY {0,0,0,0,0,0}
#define SECURITY_WORLD_SID_AUTHORITY {0,0,0,0,0,1}
#define SECURITY_LOCAL_SID_AUTHORITY {0,0,0,0,0,2}
#define SECURITY_CREATOR_SID_AUTHORITY {0,0,0,0,0,3}
#define SECURITY_NON_UNIQUE_AUTHORITY {0,0,0,0,0,4}
#define SECURITY_RESOURCE_MANAGER_AUTHORITY {0,0,0,0,0,9}

#define SECURITY_NULL_RID (__MSABI_LONG(0x00000000))
#define SECURITY_WORLD_RID (__MSABI_LONG(0x00000000))
#define SECURITY_LOCAL_RID (__MSABI_LONG(0x00000000))
#define SECURITY_LOCAL_LOGON_RID (__MSABI_LONG(0x00000001))

#define SECURITY_CREATOR_OWNER_RID (__MSABI_LONG(0x00000000))
#define SECURITY_CREATOR_GROUP_RID (__MSABI_LONG(0x00000001))
#define SECURITY_CREATOR_OWNER_SERVER_RID (__MSABI_LONG(0x00000002))
#define SECURITY_CREATOR_GROUP_SERVER_RID (__MSABI_LONG(0x00000003))
#define SECURITY_CREATOR_OWNER_RIGHTS_RID (__MSABI_LONG(0x00000004))

#define SECURITY_NT_AUTHORITY {0,0,0,0,0,5}

#define SECURITY_DIALUP_RID (__MSABI_LONG(0x00000001))
#define SECURITY_NETWORK_RID (__MSABI_LONG(0x00000002))
#define SECURITY_BATCH_RID (__MSABI_LONG(0x00000003))
#define SECURITY_INTERACTIVE_RID (__MSABI_LONG(0x00000004))
#define SECURITY_LOGON_IDS_RID (__MSABI_LONG(0x00000005))
#define SECURITY_LOGON_IDS_RID_COUNT (__MSABI_LONG(3))
#define SECURITY_SERVICE_RID (__MSABI_LONG(0x00000006))
#define SECURITY_ANONYMOUS_LOGON_RID (__MSABI_LONG(0x00000007))
#define SECURITY_PROXY_RID (__MSABI_LONG(0x00000008))
#define SECURITY_ENTERPRISE_CONTROLLERS_RID (__MSABI_LONG(0x00000009))
#define SECURITY_SERVER_LOGON_RID SECURITY_ENTERPRISE_CONTROLLERS_RID
#define SECURITY_PRINCIPAL_SELF_RID (__MSABI_LONG(0x0000000A))
#define SECURITY_AUTHENTICATED_USER_RID (__MSABI_LONG(0x0000000B))
#define SECURITY_RESTRICTED_CODE_RID (__MSABI_LONG(0x0000000C))
#define SECURITY_TERMINAL_SERVER_RID (__MSABI_LONG(0x0000000D))
#define SECURITY_REMOTE_LOGON_RID (__MSABI_LONG(0x0000000E))
#define SECURITY_THIS_ORGANIZATION_RID (__MSABI_LONG(0x0000000F))
#define SECURITY_IUSER_RID (__MSABI_LONG(0x00000011))
#define SECURITY_LOCAL_SYSTEM_RID (__MSABI_LONG(0x00000012))
#define SECURITY_LOCAL_SERVICE_RID (__MSABI_LONG(0x00000013))
#define SECURITY_NETWORK_SERVICE_RID (__MSABI_LONG(0x00000014))

#define SECURITY_NT_NON_UNIQUE (__MSABI_LONG(0x00000015))
#define SECURITY_NT_NON_UNIQUE_SUB_AUTH_COUNT (__MSABI_LONG(3))

#define SECURITY_ENTERPRISE_READONLY_CONTROLLERS_RID (__MSABI_LONG(0x00000016))

#define SECURITY_BUILTIN_DOMAIN_RID (__MSABI_LONG(0x00000020))
#define SECURITY_WRITE_RESTRICTED_CODE_RID (__MSABI_LONG(0x00000021))

#define SECURITY_PACKAGE_BASE_RID (__MSABI_LONG(0x00000040))
#define SECURITY_PACKAGE_RID_COUNT (__MSABI_LONG(2))
#define SECURITY_PACKAGE_NTLM_RID (__MSABI_LONG(0x0000000A))
#define SECURITY_PACKAGE_SCHANNEL_RID (__MSABI_LONG(0x0000000E))
#define SECURITY_PACKAGE_DIGEST_RID (__MSABI_LONG(0x00000015))

#define SECURITY_CRED_TYPE_BASE_RID (__MSABI_LONG(0x00000041))
#define SECURITY_CRED_TYPE_RID_COUNT (__MSABI_LONG(2))
#define SECURITY_CRED_TYPE_THIS_ORG_CERT_RID (__MSABI_LONG(0x00000001))

#define SECURITY_MIN_BASE_RID (__MSABI_LONG(0x00000050))

#define SECURITY_SERVICE_ID_BASE_RID (__MSABI_LONG(0x00000050))
#define SECURITY_SERVICE_ID_RID_COUNT (__MSABI_LONG(6))

#define SECURITY_RESERVED_ID_BASE_RID (__MSABI_LONG(0x00000051))

#define SECURITY_APPPOOL_ID_BASE_RID (__MSABI_LONG(0x00000052))
#define SECURITY_APPPOOL_ID_RID_COUNT (__MSABI_LONG(6))

#define SECURITY_VIRTUALSERVER_ID_BASE_RID (__MSABI_LONG(0x00000053))
#define SECURITY_VIRTUALSERVER_ID_RID_COUNT (__MSABI_LONG(6))

#define SECURITY_USERMODEDRIVERHOST_ID_BASE_RID (__MSABI_LONG(0x00000054))
#define SECURITY_USERMODEDRIVERHOST_ID_RID_COUNT (__MSABI_LONG(6))

#define SECURITY_CLOUD_INFRASTRUCTURE_SERVICES_ID_BASE_RID (__MSABI_LONG(0x00000055))
#define SECURITY_CLOUD_INFRASTRUCTURE_SERVICES_ID_RID_COUNT (__MSABI_LONG(6))

#define SECURITY_WMIHOST_ID_BASE_RID (__MSABI_LONG(0x00000056))
#define SECURITY_WMIHOST_ID_RID_COUNT (__MSABI_LONG(6))

#define SECURITY_TASK_ID_BASE_RID (__MSABI_LONG(0x00000057))

#define SECURITY_NFS_ID_BASE_RID (__MSABI_LONG(0x00000058))

#define SECURITY_COM_ID_BASE_RID (__MSABI_LONG(0x00000059))

#define SECURITY_WINDOW_MANAGER_BASE_RID (__MSABI_LONG(0x0000005a))

#define SECURITY_RDV_GFX_BASE_RID (__MSABI_LONG(0x0000005b))

#define SECURITY_DASHOST_ID_BASE_RID (__MSABI_LONG(0x0000005c))
#define SECURITY_DASHOST_ID_RID_COUNT (__MSABI_LONG(6))

#define SECURITY_VIRTUALACCOUNT_ID_RID_COUNT (__MSABI_LONG(6))

#define SECURITY_MAX_BASE_RID (__MSABI_LONG(0x0000006f))

#define SECURITY_MAX_ALWAYS_FILTERED (__MSABI_LONG(0x000003E7))
#define SECURITY_MIN_NEVER_FILTERED (__MSABI_LONG(0x000003E8))

#define SECURITY_OTHER_ORGANIZATION_RID (__MSABI_LONG(0x000003E8))

#define SECURITY_WINDOWSMOBILE_ID_BASE_RID (__MSABI_LONG(0x00000070))

#define DOMAIN_GROUP_RID_AUTHORIZATION_DATA_IS_COMPOUNDED (__MSABI_LONG(0x000001f0))
#define DOMAIN_GROUP_RID_AUTHORIZATION_DATA_CONTAINS_CLAIMS (__MSABI_LONG(0x000001f1))
#define DOMAIN_GROUP_RID_ENTERPRISE_READONLY_DOMAIN_CONTROLLERS (__MSABI_LONG(0x000001f2))

#define FOREST_USER_RID_MAX (__MSABI_LONG(0x000001F3))

#define DOMAIN_USER_RID_ADMIN (__MSABI_LONG(0x000001F4))
#define DOMAIN_USER_RID_GUEST (__MSABI_LONG(0x000001F5))
#define DOMAIN_USER_RID_KRBTGT (__MSABI_LONG(0x000001F6))

#define DOMAIN_USER_RID_MAX (__MSABI_LONG(0x000003E7))

#define DOMAIN_GROUP_RID_ADMINS (__MSABI_LONG(0x00000200))
#define DOMAIN_GROUP_RID_USERS (__MSABI_LONG(0x00000201))
#define DOMAIN_GROUP_RID_GUESTS (__MSABI_LONG(0x00000202))
#define DOMAIN_GROUP_RID_COMPUTERS (__MSABI_LONG(0x00000203))
#define DOMAIN_GROUP_RID_CONTROLLERS (__MSABI_LONG(0x00000204))
#define DOMAIN_GROUP_RID_CERT_ADMINS (__MSABI_LONG(0x00000205))
#define DOMAIN_GROUP_RID_SCHEMA_ADMINS (__MSABI_LONG(0x00000206))
#define DOMAIN_GROUP_RID_ENTERPRISE_ADMINS (__MSABI_LONG(0x00000207))
#define DOMAIN_GROUP_RID_POLICY_ADMINS (__MSABI_LONG(0x00000208))
#define DOMAIN_GROUP_RID_READONLY_CONTROLLERS (__MSABI_LONG(0x00000209))
#define DOMAIN_GROUP_RID_CLONEABLE_CONTROLLERS (__MSABI_LONG(0x0000020a))

#define DOMAIN_ALIAS_RID_ADMINS (__MSABI_LONG(0x00000220))
#define DOMAIN_ALIAS_RID_USERS (__MSABI_LONG(0x00000221))
#define DOMAIN_ALIAS_RID_GUESTS (__MSABI_LONG(0x00000222))
#define DOMAIN_ALIAS_RID_POWER_USERS (__MSABI_LONG(0x00000223))

#define DOMAIN_ALIAS_RID_ACCOUNT_OPS (__MSABI_LONG(0x00000224))
#define DOMAIN_ALIAS_RID_SYSTEM_OPS (__MSABI_LONG(0x00000225))
#define DOMAIN_ALIAS_RID_PRINT_OPS (__MSABI_LONG(0x00000226))
#define DOMAIN_ALIAS_RID_BACKUP_OPS (__MSABI_LONG(0x00000227))

#define DOMAIN_ALIAS_RID_REPLICATOR (__MSABI_LONG(0x00000228))
#define DOMAIN_ALIAS_RID_RAS_SERVERS (__MSABI_LONG(0x00000229))
#define DOMAIN_ALIAS_RID_PREW2KCOMPACCESS (__MSABI_LONG(0x0000022A))
#define DOMAIN_ALIAS_RID_REMOTE_DESKTOP_USERS (__MSABI_LONG(0x0000022B))
#define DOMAIN_ALIAS_RID_NETWORK_CONFIGURATION_OPS (__MSABI_LONG(0x0000022C))
#define DOMAIN_ALIAS_RID_INCOMING_FOREST_TRUST_BUILDERS (__MSABI_LONG(0x0000022D))

#define DOMAIN_ALIAS_RID_MONITORING_USERS (__MSABI_LONG(0x0000022E))
#define DOMAIN_ALIAS_RID_LOGGING_USERS (__MSABI_LONG(0x0000022F))
#define DOMAIN_ALIAS_RID_AUTHORIZATIONACCESS (__MSABI_LONG(0x00000230))
#define DOMAIN_ALIAS_RID_TS_LICENSE_SERVERS (__MSABI_LONG(0x00000231))
#define DOMAIN_ALIAS_RID_DCOM_USERS (__MSABI_LONG(0x00000232))

#define DOMAIN_ALIAS_RID_IUSERS (__MSABI_LONG(0x00000238))
#define DOMAIN_ALIAS_RID_CRYPTO_OPERATORS (__MSABI_LONG(0x00000239))
#define DOMAIN_ALIAS_RID_CACHEABLE_PRINCIPALS_GROUP (__MSABI_LONG(0x0000023B))
#define DOMAIN_ALIAS_RID_NON_CACHEABLE_PRINCIPALS_GROUP (__MSABI_LONG(0x0000023C))
#define DOMAIN_ALIAS_RID_EVENT_LOG_READERS_GROUP (__MSABI_LONG(0x0000023D))
#define DOMAIN_ALIAS_RID_CERTSVC_DCOM_ACCESS_GROUP (__MSABI_LONG(0x0000023e))
#define DOMAIN_ALIAS_RID_RDS_REMOTE_ACCESS_SERVERS (__MSABI_LONG(0x0000023f))
#define DOMAIN_ALIAS_RID_RDS_ENDPOINT_SERVERS (__MSABI_LONG(0x00000240))
#define DOMAIN_ALIAS_RID_RDS_MANAGEMENT_SERVERS (__MSABI_LONG(0x00000241))
#define DOMAIN_ALIAS_RID_HYPER_V_ADMINS (__MSABI_LONG(0x00000242))
#define DOMAIN_ALIAS_RID_ACCESS_CONTROL_ASSISTANCE_OPS (__MSABI_LONG(0x00000243))
#define DOMAIN_ALIAS_RID_REMOTE_MANAGEMENT_USERS (__MSABI_LONG(0x00000244))

#define SECURITY_APP_PACKAGE_AUTHORITY {0, 0, 0, 0, 0, 15}

#define SECURITY_APP_PACKAGE_BASE_RID (__MSABI_LONG(0x00000002))
#define SECURITY_BUILTIN_APP_PACKAGE_RID_COUNT (__MSABI_LONG(2))
#define SECURITY_APP_PACKAGE_RID_COUNT (__MSABI_LONG(8))
#define SECURITY_CAPABILITY_BASE_RID (__MSABI_LONG(0x00000003))
#define SECURITY_BUILTIN_CAPABILITY_RID_COUNT (__MSABI_LONG(2))
#define SECURITY_CAPABILITY_RID_COUNT (__MSABI_LONG(5))

#define SECURITY_BUILTIN_PACKAGE_ANY_PACKAGE (__MSABI_LONG(0x00000001))
#define SECURITY_BUILTIN_PACKAGE_ANY_RESTRICTED_PACKAGE (__MSABI_LONG(0x00000002))

#define SECURITY_CAPABILITY_INTERNET_CLIENT (__MSABI_LONG(0x00000001))
#define SECURITY_CAPABILITY_INTERNET_CLIENT_SERVER (__MSABI_LONG(0x00000002))
#define SECURITY_CAPABILITY_PRIVATE_NETWORK_CLIENT_SERVER (__MSABI_LONG(0x00000003))
#define SECURITY_CAPABILITY_PICTURES_LIBRARY (__MSABI_LONG(0x00000004))
#define SECURITY_CAPABILITY_VIDEOS_LIBRARY (__MSABI_LONG(0x00000005))
#define SECURITY_CAPABILITY_MUSIC_LIBRARY (__MSABI_LONG(0x00000006))
#define SECURITY_CAPABILITY_DOCUMENTS_LIBRARY (__MSABI_LONG(0x00000007))
#define SECURITY_CAPABILITY_ENTERPRISE_AUTHENTICATION (__MSABI_LONG(0x00000008))
#define SECURITY_CAPABILITY_SHARED_USER_CERTIFICATES (__MSABI_LONG(0x00000009))
#define SECURITY_CAPABILITY_REMOVABLE_STORAGE (__MSABI_LONG(0x0000000a))
#define SECURITY_CAPABILITY_APPOINTMENTS (__MSABI_LONG(0x0000000b))
#define SECURITY_CAPABILITY_CONTACTS (__MSABI_LONG(0x0000000c))
#define SECURITY_CAPABILITY_INTERNET_EXPLORER (__MSABI_LONG(0x00001000))



#define SECURITY_MANDATORY_LABEL_AUTHORITY {0,0,0,0,0,16}
#define SECURITY_MANDATORY_UNTRUSTED_RID (__MSABI_LONG(0x00000000))
#define SECURITY_MANDATORY_LOW_RID (__MSABI_LONG(0x00001000))
#define SECURITY_MANDATORY_MEDIUM_RID (__MSABI_LONG(0x00002000))
#define SECURITY_MANDATORY_HIGH_RID (__MSABI_LONG(0x00003000))
#define SECURITY_MANDATORY_SYSTEM_RID (__MSABI_LONG(0x00004000))
#define SECURITY_MANDATORY_PROTECTED_PROCESS_RID (__MSABI_LONG(0x00005000))

#define SECURITY_MANDATORY_MAXIMUM_USER_RID SECURITY_MANDATORY_SYSTEM_RID

#define MANDATORY_LEVEL_TO_MANDATORY_RID(IL) (IL * 0x1000)

#define SECURITY_SCOPED_POLICY_ID_AUTHORITY {0, 0, 0, 0, 0, 17}

#define SECURITY_AUTHENTICATION_AUTHORITY {0, 0, 0, 0, 0, 18}
#define SECURITY_AUTHENTICATION_AUTHORITY_RID_COUNT (__MSABI_LONG(1))
#define SECURITY_AUTHENTICATION_AUTHORITY_ASSERTED_RID (__MSABI_LONG(0x00000001))
#define SECURITY_AUTHENTICATION_SERVICE_ASSERTED_RID (__MSABI_LONG(0x00000002))

#define SECURITY_TRUSTED_INSTALLER_RID1 956008885
#define SECURITY_TRUSTED_INSTALLER_RID2 3418522649
#define SECURITY_TRUSTED_INSTALLER_RID3 1831038044
#define SECURITY_TRUSTED_INSTALLER_RID4 1853292631
#define SECURITY_TRUSTED_INSTALLER_RID5 2271478464

    typedef enum {
      WinNullSid = 0,WinWorldSid = 1,WinLocalSid = 2,WinCreatorOwnerSid = 3,
      WinCreatorGroupSid = 4,WinCreatorOwnerServerSid = 5,
      WinCreatorGroupServerSid = 6,WinNtAuthoritySid = 7,WinDialupSid = 8,
      WinNetworkSid = 9,WinBatchSid = 10,WinInteractiveSid = 11,
      WinServiceSid = 12,WinAnonymousSid = 13,WinProxySid = 14,
      WinEnterpriseControllersSid = 15,WinSelfSid = 16,
      WinAuthenticatedUserSid = 17,WinRestrictedCodeSid = 18,
      WinTerminalServerSid = 19,WinRemoteLogonIdSid = 20,WinLogonIdsSid = 21,
      WinLocalSystemSid = 22,WinLocalServiceSid = 23,WinNetworkServiceSid = 24,
      WinBuiltinDomainSid = 25,WinBuiltinAdministratorsSid = 26,
      WinBuiltinUsersSid = 27,WinBuiltinGuestsSid = 28,
      WinBuiltinPowerUsersSid = 29,WinBuiltinAccountOperatorsSid = 30,
      WinBuiltinSystemOperatorsSid = 31,WinBuiltinPrintOperatorsSid = 32,
      WinBuiltinBackupOperatorsSid = 33,WinBuiltinReplicatorSid = 34,
      WinBuiltinPreWindows2000CompatibleAccessSid = 35,
      WinBuiltinRemoteDesktopUsersSid = 36,
      WinBuiltinNetworkConfigurationOperatorsSid = 37,
      WinAccountAdministratorSid = 38,WinAccountGuestSid = 39,
      WinAccountKrbtgtSid = 40,WinAccountDomainAdminsSid = 41,
      WinAccountDomainUsersSid = 42,WinAccountDomainGuestsSid = 43,
      WinAccountComputersSid = 44,WinAccountControllersSid = 45,
      WinAccountCertAdminsSid = 46,WinAccountSchemaAdminsSid = 47,
      WinAccountEnterpriseAdminsSid = 48,WinAccountPolicyAdminsSid = 49,
      WinAccountRasAndIasServersSid = 50,WinNTLMAuthenticationSid = 51,
      WinDigestAuthenticationSid = 52,WinSChannelAuthenticationSid = 53,
      WinThisOrganizationSid = 54,WinOtherOrganizationSid = 55,
      WinBuiltinIncomingForestTrustBuildersSid = 56,
      WinBuiltinPerfMonitoringUsersSid = 57,WinBuiltinPerfLoggingUsersSid = 58,
      WinBuiltinAuthorizationAccessSid = 59,
      WinBuiltinTerminalServerLicenseServersSid = 60,
      WinBuiltinDCOMUsersSid = 61,WinBuiltinIUsersSid = 62,
      WinIUserSid = 63, WinBuiltinCryptoOperatorsSid = 64,
      WinUntrustedLabelSid = 65, WinLowLabelSid = 66, WinMediumLabelSid = 67,
      WinHighLabelSid = 68, WinSystemLabelSid = 69, WinWriteRestrictedCodeSid = 70,
      WinCreatorOwnerRightsSid = 71, WinCacheablePrincipalsGroupSid = 72,
      WinNonCacheablePrincipalsGroupSid = 73, WinEnterpriseReadonlyControllersSid = 74,
      WinAccountReadonlyControllersSid = 75, WinBuiltinEventLogReadersGroup = 76,
      WinNewEnterpriseReadonlyControllersSid = 77, WinBuiltinCertSvcDComAccessGroup = 78,
      WinMediumPlusLabelSid = 79, WinLocalLogonSid = 80, WinConsoleLogonSid = 81,
      WinThisOrganizationCertificateSid = 82, WinApplicationPackageAuthoritySid = 83,
      WinBuiltinAnyPackageSid = 84, WinCapabilityInternetClientSid = 85,
      WinCapabilityInternetClientServerSid = 86,
      WinCapabilityPrivateNetworkClientServerSid = 87,
      WinCapabilityPicturesLibrarySid = 88, WinCapabilityVideosLibrarySid = 89,
      WinCapabilityMusicLibrarySid = 90, WinCapabilityDocumentsLibrarySid = 91,
      WinCapabilitySharedUserCertificatesSid = 92, WinCapabilityEnterpriseAuthenticationSid = 93,
      WinCapabilityRemovableStorageSid = 94, WinBuiltinRDSRemoteAccessServersSid = 95,
      WinBuiltinRDSEndpointServersSid = 96, WinBuiltinRDSManagementServersSid = 97,
      WinUserModeDriversSid = 98, WinBuiltinHyperVAdminsSid = 99,
      WinAccountCloneableControllersSid = 100,
      WinBuiltinAccessControlAssistanceOperatorsSid = 101,
      WinBuiltinRemoteManagementUsersSid = 102, WinAuthenticationAuthorityAssertedSid = 103,
      WinAuthenticationServiceAssertedSid = 104,
      WinLocalAccountSid = 105,
      WinLocalAccountAndAdministratorSid = 106,
      WinAccountProtectedUsersSid = 107,
      WinCapabilityAppointmentsSid = 108,
      WinCapabilityContactsSid = 109,
      WinAccountDefaultSystemManagedSid = 110,
      WinBuiltinDefaultSystemManagedGroupSid = 111,
      WinBuiltinStorageReplicaAdminsSid = 112,
      WinAccountKeyAdminsSid = 113,
      WinAccountEnterpriseKeyAdminsSid = 114,
      WinAuthenticationKeyTrustSid = 115,
      WinAuthenticationKeyPropertyMFASid = 116,
      WinAuthenticationKeyPropertyAttestationSid = 117
} WELL_KNOWN_SID_TYPE;

#define SYSTEM_LUID { 0x3e7, 0x0 }
#define ANONYMOUS_LOGON_LUID { 0x3e6, 0x0 }
#define LOCALSERVICE_LUID { 0x3e5, 0x0 }
#define NETWORKSERVICE_LUID { 0x3e4, 0x0 }
#define IUSER_LUID { 0x3e3, 0x0 }

#define SE_GROUP_MANDATORY (__MSABI_LONG(0x00000001))
#define SE_GROUP_ENABLED_BY_DEFAULT (__MSABI_LONG(0x00000002))
#define SE_GROUP_ENABLED (__MSABI_LONG(0x00000004))
#define SE_GROUP_OWNER (__MSABI_LONG(0x00000008))
#define SE_GROUP_USE_FOR_DENY_ONLY (__MSABI_LONG(0x00000010))
#define SE_GROUP_INTEGRITY (__MSABI_LONG(0x00000020))
#define SE_GROUP_INTEGRITY_ENABLED (__MSABI_LONG(0x00000040))
#define SE_GROUP_LOGON_ID (__MSABI_LONG(0xC0000000))
#define SE_GROUP_RESOURCE (__MSABI_LONG(0x20000000))

#define SE_GROUP_VALID_ATTRIBUTES (SE_GROUP_MANDATORY | SE_GROUP_ENABLED_BY_DEFAULT | SE_GROUP_ENABLED | SE_GROUP_OWNER | SE_GROUP_USE_FOR_DENY_ONLY | SE_GROUP_LOGON_ID | SE_GROUP_RESOURCE | SE_GROUP_INTEGRITY | SE_GROUP_INTEGRITY_ENABLED)

#define ACL_REVISION (2)
#define ACL_REVISION_DS (4)

#define ACL_REVISION1 (1)
#define MIN_ACL_REVISION ACL_REVISION2
#define ACL_REVISION2 (2)
#define ACL_REVISION3 (3)
#define ACL_REVISION4 (4)
#define MAX_ACL_REVISION ACL_REVISION4

    typedef struct _ACL {
      BYTE AclRevision;
      BYTE Sbz1;
      WORD AclSize;
      WORD AceCount;
      WORD Sbz2;
    } ACL;
    typedef ACL *PACL;

    typedef struct _ACE_HEADER {
      BYTE AceType;
      BYTE AceFlags;
      WORD AceSize;
    } ACE_HEADER;
    typedef ACE_HEADER *PACE_HEADER;

#define ACCESS_MIN_MS_ACE_TYPE (0x0)
#define ACCESS_ALLOWED_ACE_TYPE (0x0)
#define ACCESS_DENIED_ACE_TYPE (0x1)
#define SYSTEM_AUDIT_ACE_TYPE (0x2)
#define SYSTEM_ALARM_ACE_TYPE (0x3)
#define ACCESS_MAX_MS_V2_ACE_TYPE (0x3)

#define ACCESS_ALLOWED_COMPOUND_ACE_TYPE (0x4)
#define ACCESS_MAX_MS_V3_ACE_TYPE (0x4)

#define ACCESS_MIN_MS_OBJECT_ACE_TYPE (0x5)
#define ACCESS_ALLOWED_OBJECT_ACE_TYPE (0x5)
#define ACCESS_DENIED_OBJECT_ACE_TYPE (0x6)
#define SYSTEM_AUDIT_OBJECT_ACE_TYPE (0x7)
#define SYSTEM_ALARM_OBJECT_ACE_TYPE (0x8)
#define ACCESS_MAX_MS_OBJECT_ACE_TYPE (0x8)

#define ACCESS_MAX_MS_V4_ACE_TYPE (0x8)
#define ACCESS_MAX_MS_ACE_TYPE (0x8)

#define ACCESS_ALLOWED_CALLBACK_ACE_TYPE (0x9)
#define ACCESS_DENIED_CALLBACK_ACE_TYPE (0xA)
#define ACCESS_ALLOWED_CALLBACK_OBJECT_ACE_TYPE (0xB)
#define ACCESS_DENIED_CALLBACK_OBJECT_ACE_TYPE (0xC)
#define SYSTEM_AUDIT_CALLBACK_ACE_TYPE (0xD)
#define SYSTEM_ALARM_CALLBACK_ACE_TYPE (0xE)
#define SYSTEM_AUDIT_CALLBACK_OBJECT_ACE_TYPE (0xF)
#define SYSTEM_ALARM_CALLBACK_OBJECT_ACE_TYPE (0x10)

#define SYSTEM_MANDATORY_LABEL_ACE_TYPE (0x11)
#define SYSTEM_RESOURCE_ATTRIBUTE_ACE_TYPE (0x12)
#define SYSTEM_SCOPED_POLICY_ID_ACE_TYPE (0x13)
#define ACCESS_MAX_MS_V5_ACE_TYPE (0x13)

#define OBJECT_INHERIT_ACE (0x1)
#define CONTAINER_INHERIT_ACE (0x2)
#define NO_PROPAGATE_INHERIT_ACE (0x4)
#define INHERIT_ONLY_ACE (0x8)
#define INHERITED_ACE (0x10)
#define VALID_INHERIT_FLAGS (0x1F)

#define SUCCESSFUL_ACCESS_ACE_FLAG (0x40)
#define FAILED_ACCESS_ACE_FLAG (0x80)

    typedef struct _ACCESS_ALLOWED_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD SidStart;
    } ACCESS_ALLOWED_ACE;

    typedef ACCESS_ALLOWED_ACE *PACCESS_ALLOWED_ACE;

    typedef struct _ACCESS_DENIED_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD SidStart;
    } ACCESS_DENIED_ACE;
    typedef ACCESS_DENIED_ACE *PACCESS_DENIED_ACE;

    typedef struct _SYSTEM_AUDIT_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD SidStart;
    } SYSTEM_AUDIT_ACE;
    typedef SYSTEM_AUDIT_ACE *PSYSTEM_AUDIT_ACE;

    typedef struct _SYSTEM_ALARM_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD SidStart;
    } SYSTEM_ALARM_ACE;
    typedef SYSTEM_ALARM_ACE *PSYSTEM_ALARM_ACE;

    typedef struct _SYSTEM_RESOURCE_ATTRIBUTE_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD SidStart;
    } SYSTEM_RESOURCE_ATTRIBUTE_ACE,*PSYSTEM_RESOURCE_ATTRIBUTE_ACE;

    typedef struct _SYSTEM_SCOPED_POLICY_ID_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD SidStart;
    } SYSTEM_SCOPED_POLICY_ID_ACE,*PSYSTEM_SCOPED_POLICY_ID_ACE;

    typedef struct _SYSTEM_MANDATORY_LABEL_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD SidStart;
    } SYSTEM_MANDATORY_LABEL_ACE, *PSYSTEM_MANDATORY_LABEL_ACE;

#define SYSTEM_MANDATORY_LABEL_NO_WRITE_UP 0x1
#define SYSTEM_MANDATORY_LABEL_NO_READ_UP 0x2
#define SYSTEM_MANDATORY_LABEL_NO_EXECUTE_UP 0x4

#define SYSTEM_MANDATORY_LABEL_VALID_MASK (SYSTEM_MANDATORY_LABEL_NO_WRITE_UP | SYSTEM_MANDATORY_LABEL_NO_READ_UP | SYSTEM_MANDATORY_LABEL_NO_EXECUTE_UP)

    typedef struct _ACCESS_ALLOWED_OBJECT_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD Flags;
      GUID ObjectType;
      GUID InheritedObjectType;
      DWORD SidStart;
    } ACCESS_ALLOWED_OBJECT_ACE,*PACCESS_ALLOWED_OBJECT_ACE;

    typedef struct _ACCESS_DENIED_OBJECT_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD Flags;
      GUID ObjectType;
      GUID InheritedObjectType;
      DWORD SidStart;
    } ACCESS_DENIED_OBJECT_ACE,*PACCESS_DENIED_OBJECT_ACE;

    typedef struct _SYSTEM_AUDIT_OBJECT_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD Flags;
      GUID ObjectType;
      GUID InheritedObjectType;
      DWORD SidStart;
    } SYSTEM_AUDIT_OBJECT_ACE,*PSYSTEM_AUDIT_OBJECT_ACE;

    typedef struct _SYSTEM_ALARM_OBJECT_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD Flags;
      GUID ObjectType;
      GUID InheritedObjectType;
      DWORD SidStart;
    } SYSTEM_ALARM_OBJECT_ACE,*PSYSTEM_ALARM_OBJECT_ACE;

    typedef struct _ACCESS_ALLOWED_CALLBACK_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD SidStart;
    } ACCESS_ALLOWED_CALLBACK_ACE,*PACCESS_ALLOWED_CALLBACK_ACE;

    typedef struct _ACCESS_DENIED_CALLBACK_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD SidStart;
    } ACCESS_DENIED_CALLBACK_ACE,*PACCESS_DENIED_CALLBACK_ACE;

    typedef struct _SYSTEM_AUDIT_CALLBACK_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD SidStart;
    } SYSTEM_AUDIT_CALLBACK_ACE,*PSYSTEM_AUDIT_CALLBACK_ACE;

    typedef struct _SYSTEM_ALARM_CALLBACK_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD SidStart;
    } SYSTEM_ALARM_CALLBACK_ACE,*PSYSTEM_ALARM_CALLBACK_ACE;

    typedef struct _ACCESS_ALLOWED_CALLBACK_OBJECT_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD Flags;
      GUID ObjectType;
      GUID InheritedObjectType;
      DWORD SidStart;

    } ACCESS_ALLOWED_CALLBACK_OBJECT_ACE,*PACCESS_ALLOWED_CALLBACK_OBJECT_ACE;

    typedef struct _ACCESS_DENIED_CALLBACK_OBJECT_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD Flags;
      GUID ObjectType;
      GUID InheritedObjectType;
      DWORD SidStart;
    } ACCESS_DENIED_CALLBACK_OBJECT_ACE,*PACCESS_DENIED_CALLBACK_OBJECT_ACE;

    typedef struct _SYSTEM_AUDIT_CALLBACK_OBJECT_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD Flags;
      GUID ObjectType;
      GUID InheritedObjectType;
      DWORD SidStart;
    } SYSTEM_AUDIT_CALLBACK_OBJECT_ACE,*PSYSTEM_AUDIT_CALLBACK_OBJECT_ACE;

    typedef struct _SYSTEM_ALARM_CALLBACK_OBJECT_ACE {
      ACE_HEADER Header;
      ACCESS_MASK Mask;
      DWORD Flags;
      GUID ObjectType;
      GUID InheritedObjectType;
      DWORD SidStart;

    } SYSTEM_ALARM_CALLBACK_OBJECT_ACE,*PSYSTEM_ALARM_CALLBACK_OBJECT_ACE;

#define ACE_OBJECT_TYPE_PRESENT 0x1
#define ACE_INHERITED_OBJECT_TYPE_PRESENT 0x2

    typedef enum _ACL_INFORMATION_CLASS {
      AclRevisionInformation = 1,AclSizeInformation
    } ACL_INFORMATION_CLASS;

    typedef struct _ACL_REVISION_INFORMATION {
      DWORD AclRevision;
    } ACL_REVISION_INFORMATION;
    typedef ACL_REVISION_INFORMATION *PACL_REVISION_INFORMATION;

    typedef struct _ACL_SIZE_INFORMATION {
      DWORD AceCount;
      DWORD AclBytesInUse;
      DWORD AclBytesFree;
    } ACL_SIZE_INFORMATION;
    typedef ACL_SIZE_INFORMATION *PACL_SIZE_INFORMATION;

#define SECURITY_DESCRIPTOR_REVISION (1)
#define SECURITY_DESCRIPTOR_REVISION1 (1)

#define SECURITY_DESCRIPTOR_MIN_LENGTH (sizeof(SECURITY_DESCRIPTOR))

    typedef WORD SECURITY_DESCRIPTOR_CONTROL,*PSECURITY_DESCRIPTOR_CONTROL;

#define SE_OWNER_DEFAULTED (0x0001)
#define SE_GROUP_DEFAULTED (0x0002)
#define SE_DACL_PRESENT (0x0004)
#define SE_DACL_DEFAULTED (0x0008)
#define SE_SACL_PRESENT (0x0010)
#define SE_SACL_DEFAULTED (0x0020)
#define SE_DACL_AUTO_INHERIT_REQ (0x0100)
#define SE_SACL_AUTO_INHERIT_REQ (0x0200)
#define SE_DACL_AUTO_INHERITED (0x0400)
#define SE_SACL_AUTO_INHERITED (0x0800)
#define SE_DACL_PROTECTED (0x1000)
#define SE_SACL_PROTECTED (0x2000)
#define SE_RM_CONTROL_VALID (0x4000)
#define SE_SELF_RELATIVE (0x8000)

    typedef struct _SECURITY_DESCRIPTOR_RELATIVE {
      BYTE Revision;
      BYTE Sbz1;
      SECURITY_DESCRIPTOR_CONTROL Control;
      DWORD Owner;
      DWORD Group;
      DWORD Sacl;
      DWORD Dacl;
    } SECURITY_DESCRIPTOR_RELATIVE,*PISECURITY_DESCRIPTOR_RELATIVE;

    typedef struct _SECURITY_DESCRIPTOR {
      BYTE Revision;
      BYTE Sbz1;
      SECURITY_DESCRIPTOR_CONTROL Control;
      PSID Owner;
      PSID Group;
      PACL Sacl;
      PACL Dacl;
    } SECURITY_DESCRIPTOR,*PISECURITY_DESCRIPTOR;

    typedef struct _OBJECT_TYPE_LIST {
      WORD Level;
      WORD Sbz;
      GUID *ObjectType;
    } OBJECT_TYPE_LIST,*POBJECT_TYPE_LIST;

#define ACCESS_OBJECT_GUID 0
#define ACCESS_PROPERTY_SET_GUID 1
#define ACCESS_PROPERTY_GUID 2

#define ACCESS_MAX_LEVEL 4

    typedef enum _AUDIT_EVENT_TYPE {
      AuditEventObjectAccess,AuditEventDirectoryServiceAccess
    } AUDIT_EVENT_TYPE,*PAUDIT_EVENT_TYPE;

#define AUDIT_ALLOW_NO_PRIVILEGE 0x1

#define ACCESS_DS_SOURCE_A "DS"
#define ACCESS_DS_SOURCE_W L"DS"
#define ACCESS_DS_OBJECT_TYPE_NAME_A "Directory Service Object"
#define ACCESS_DS_OBJECT_TYPE_NAME_W L"Directory Service Object"

#define SE_PRIVILEGE_ENABLED_BY_DEFAULT (__MSABI_LONG(0x00000001))
#define SE_PRIVILEGE_ENABLED (__MSABI_LONG(0x00000002))
#define SE_PRIVILEGE_REMOVED (0X00000004L)
#define SE_PRIVILEGE_USED_FOR_ACCESS (__MSABI_LONG(0x80000000))

#define SE_PRIVILEGE_VALID_ATTRIBUTES (SE_PRIVILEGE_ENABLED_BY_DEFAULT | SE_PRIVILEGE_ENABLED | SE_PRIVILEGE_REMOVED | SE_PRIVILEGE_USED_FOR_ACCESS)

#define PRIVILEGE_SET_ALL_NECESSARY (1)

    typedef struct _PRIVILEGE_SET {
      DWORD PrivilegeCount;
      DWORD Control;
      LUID_AND_ATTRIBUTES Privilege[ANYSIZE_ARRAY];
    } PRIVILEGE_SET,*PPRIVILEGE_SET;

#define ACCESS_REASON_TYPE_MASK 0x00ff0000
#define ACCESS_REASON_DATA_MASK 0x0000ffff

#define ACCESS_REASON_STAGING_MASK 0x80000000
#define ACCESS_REASON_EXDATA_MASK 0x7f000000

    typedef enum _ACCESS_REASON_TYPE {
      AccessReasonNone = 0x00000000,
      AccessReasonAllowedAce = 0x00010000,
      AccessReasonDeniedAce = 0x00020000,
      AccessReasonAllowedParentAce = 0x00030000,
      AccessReasonDeniedParentAce = 0x00040000,
      AccessReasonNotGrantedByCape = 0x00050000,
      AccessReasonNotGrantedByParentCape = 0x00060000,
      AccessReasonNotGrantedToAppContainer = 0x00070000,
      AccessReasonMissingPrivilege = 0x00100000,
      AccessReasonFromPrivilege = 0x00200000,
      AccessReasonIntegrityLevel = 0x00300000,
      AccessReasonOwnership = 0x00400000,
      AccessReasonNullDacl = 0x00500000,
      AccessReasonEmptyDacl = 0x00600000,
      AccessReasonNoSD = 0x00700000,
      AccessReasonNoGrant = 0x00800000
    } ACCESS_REASON_TYPE;
    typedef DWORD ACCESS_REASON;

    typedef struct _ACCESS_REASONS {
      ACCESS_REASON Data[32];
    } ACCESS_REASONS,*PACCESS_REASONS;

#define SE_SECURITY_DESCRIPTOR_FLAG_NO_OWNER_ACE 0x00000001
#define SE_SECURITY_DESCRIPTOR_FLAG_NO_LABEL_ACE 0x00000002
#define SE_SECURITY_DESCRIPTOR_VALID_FLAGS 0x00000003

    typedef struct _SE_SECURITY_DESCRIPTOR {
      DWORD Size;
      DWORD Flags;
      PSECURITY_DESCRIPTOR SecurityDescriptor;
    } SE_SECURITY_DESCRIPTOR,*PSE_SECURITY_DESCRIPTOR;

    typedef struct _SE_ACCESS_REQUEST {
      DWORD Size;
      PSE_SECURITY_DESCRIPTOR SeSecurityDescriptor;
      ACCESS_MASK DesiredAccess;
      ACCESS_MASK PreviouslyGrantedAccess;
      PSID PrincipalSelfSid;
      PGENERIC_MAPPING GenericMapping;
      DWORD ObjectTypeListCount;
      POBJECT_TYPE_LIST ObjectTypeList;
    } SE_ACCESS_REQUEST,*PSE_ACCESS_REQUEST;

    typedef struct _SE_ACCESS_REPLY {
      DWORD Size;
      DWORD ResultListCount;
      PACCESS_MASK GrantedAccess;
      PDWORD AccessStatus;
      PACCESS_REASONS AccessReason;
      PPRIVILEGE_SET *Privileges;
    } SE_ACCESS_REPLY,*PSE_ACCESS_REPLY;

#define SE_CREATE_TOKEN_NAME TEXT("SeCreateTokenPrivilege")
#define SE_ASSIGNPRIMARYTOKEN_NAME TEXT("SeAssignPrimaryTokenPrivilege")
#define SE_LOCK_MEMORY_NAME TEXT("SeLockMemoryPrivilege")
#define SE_INCREASE_QUOTA_NAME TEXT("SeIncreaseQuotaPrivilege")
#define SE_UNSOLICITED_INPUT_NAME TEXT("SeUnsolicitedInputPrivilege")
#define SE_MACHINE_ACCOUNT_NAME TEXT("SeMachineAccountPrivilege")
#define SE_TCB_NAME TEXT("SeTcbPrivilege")
#define SE_SECURITY_NAME TEXT("SeSecurityPrivilege")
#define SE_TAKE_OWNERSHIP_NAME TEXT("SeTakeOwnershipPrivilege")
#define SE_LOAD_DRIVER_NAME TEXT("SeLoadDriverPrivilege")
#define SE_SYSTEM_PROFILE_NAME TEXT("SeSystemProfilePrivilege")
#define SE_SYSTEMTIME_NAME TEXT("SeSystemtimePrivilege")
#define SE_PROF_SINGLE_PROCESS_NAME TEXT("SeProfileSingleProcessPrivilege")
#define SE_INC_BASE_PRIORITY_NAME TEXT("SeIncreaseBasePriorityPrivilege")
#define SE_CREATE_PAGEFILE_NAME TEXT("SeCreatePagefilePrivilege")
#define SE_CREATE_PERMANENT_NAME TEXT("SeCreatePermanentPrivilege")
#define SE_BACKUP_NAME TEXT("SeBackupPrivilege")
#define SE_RESTORE_NAME TEXT("SeRestorePrivilege")
#define SE_SHUTDOWN_NAME TEXT("SeShutdownPrivilege")
#define SE_DEBUG_NAME TEXT("SeDebugPrivilege")
#define SE_AUDIT_NAME TEXT("SeAuditPrivilege")
#define SE_SYSTEM_ENVIRONMENT_NAME TEXT("SeSystemEnvironmentPrivilege")
#define SE_CHANGE_NOTIFY_NAME TEXT("SeChangeNotifyPrivilege")
#define SE_REMOTE_SHUTDOWN_NAME TEXT("SeRemoteShutdownPrivilege")
#define SE_UNDOCK_NAME TEXT("SeUndockPrivilege")
#define SE_SYNC_AGENT_NAME TEXT("SeSyncAgentPrivilege")
#define SE_ENABLE_DELEGATION_NAME TEXT("SeEnableDelegationPrivilege")
#define SE_MANAGE_VOLUME_NAME TEXT("SeManageVolumePrivilege")
#define SE_IMPERSONATE_NAME TEXT("SeImpersonatePrivilege")
#define SE_CREATE_GLOBAL_NAME TEXT("SeCreateGlobalPrivilege")
#define SE_TRUSTED_CREDMAN_ACCESS_NAME TEXT("SeTrustedCredManAccessPrivilege")
#define SE_RELABEL_NAME TEXT("SeRelabelPrivilege")
#define SE_INC_WORKING_SET_NAME TEXT("SeIncreaseWorkingSetPrivilege")
#define SE_TIME_ZONE_NAME TEXT("SeTimeZonePrivilege")
#define SE_CREATE_SYMBOLIC_LINK_NAME TEXT("SeCreateSymbolicLinkPrivilege")

    typedef enum _SECURITY_IMPERSONATION_LEVEL {
      SecurityAnonymous,SecurityIdentification,SecurityImpersonation,SecurityDelegation
    } SECURITY_IMPERSONATION_LEVEL,*PSECURITY_IMPERSONATION_LEVEL;

#define SECURITY_MAX_IMPERSONATION_LEVEL SecurityDelegation
#define SECURITY_MIN_IMPERSONATION_LEVEL SecurityAnonymous
#define DEFAULT_IMPERSONATION_LEVEL SecurityImpersonation
#define VALID_IMPERSONATION_LEVEL(L) (((L) >= SECURITY_MIN_IMPERSONATION_LEVEL) && ((L) <= SECURITY_MAX_IMPERSONATION_LEVEL))

#define TOKEN_ASSIGN_PRIMARY (0x0001)
#define TOKEN_DUPLICATE (0x0002)
#define TOKEN_IMPERSONATE (0x0004)
#define TOKEN_QUERY (0x0008)
#define TOKEN_QUERY_SOURCE (0x0010)
#define TOKEN_ADJUST_PRIVILEGES (0x0020)
#define TOKEN_ADJUST_GROUPS (0x0040)
#define TOKEN_ADJUST_DEFAULT (0x0080)
#define TOKEN_ADJUST_SESSIONID (0x0100)

#define TOKEN_ALL_ACCESS_P (STANDARD_RIGHTS_REQUIRED | TOKEN_ASSIGN_PRIMARY | TOKEN_DUPLICATE | TOKEN_IMPERSONATE | TOKEN_QUERY | TOKEN_QUERY_SOURCE | TOKEN_ADJUST_PRIVILEGES | TOKEN_ADJUST_GROUPS | TOKEN_ADJUST_DEFAULT)
#define TOKEN_ALL_ACCESS (TOKEN_ALL_ACCESS_P | TOKEN_ADJUST_SESSIONID)
#define TOKEN_READ (STANDARD_RIGHTS_READ | TOKEN_QUERY)

#define TOKEN_WRITE (STANDARD_RIGHTS_WRITE | TOKEN_ADJUST_PRIVILEGES | TOKEN_ADJUST_GROUPS | TOKEN_ADJUST_DEFAULT)

#define TOKEN_EXECUTE (STANDARD_RIGHTS_EXECUTE)

    typedef enum _TOKEN_TYPE {
      TokenPrimary = 1,TokenImpersonation
    } TOKEN_TYPE;
    typedef TOKEN_TYPE *PTOKEN_TYPE;

    typedef enum _TOKEN_ELEVATION_TYPE {
      TokenElevationTypeDefault   = 1,
      TokenElevationTypeFull,
      TokenElevationTypeLimited 
    } TOKEN_ELEVATION_TYPE, *PTOKEN_ELEVATION_TYPE;

    typedef enum _TOKEN_INFORMATION_CLASS {
      TokenUser = 1,
      TokenGroups,
      TokenPrivileges,
      TokenOwner,
      TokenPrimaryGroup,
      TokenDefaultDacl,
      TokenSource,
      TokenType,
      TokenImpersonationLevel,
      TokenStatistics,
      TokenRestrictedSids,
      TokenSessionId,
      TokenGroupsAndPrivileges,
      TokenSessionReference,
      TokenSandBoxInert,
      TokenAuditPolicy,
      TokenOrigin,
      TokenElevationType,
      TokenLinkedToken,
      TokenElevation,
      TokenHasRestrictions,
      TokenAccessInformation,
      TokenVirtualizationAllowed,
      TokenVirtualizationEnabled,
      TokenIntegrityLevel,
      TokenUIAccess,
      TokenMandatoryPolicy,
      TokenLogonSid,
      TokenIsAppContainer,
      TokenCapabilities,
      TokenAppContainerSid,
      TokenAppContainerNumber,
      TokenUserClaimAttributes,
      TokenDeviceClaimAttributes,
      TokenRestrictedUserClaimAttributes,
      TokenRestrictedDeviceClaimAttributes,
      TokenDeviceGroups,
      TokenRestrictedDeviceGroups,
      TokenSecurityAttributes,
      TokenIsRestricted,
      MaxTokenInfoClass
    } TOKEN_INFORMATION_CLASS,*PTOKEN_INFORMATION_CLASS;

    typedef struct _TOKEN_USER {
      SID_AND_ATTRIBUTES User;
    } TOKEN_USER,*PTOKEN_USER;

    typedef struct _TOKEN_GROUPS {
      DWORD GroupCount;
#ifdef __WIDL__
      [size_is (GroupCount)] SID_AND_ATTRIBUTES Groups[*];
#else
      SID_AND_ATTRIBUTES Groups[ANYSIZE_ARRAY];
#endif
    } TOKEN_GROUPS,*PTOKEN_GROUPS;

    typedef struct _TOKEN_PRIVILEGES {
      DWORD PrivilegeCount;
      LUID_AND_ATTRIBUTES Privileges[ANYSIZE_ARRAY];
    } TOKEN_PRIVILEGES,*PTOKEN_PRIVILEGES;

    typedef struct _TOKEN_OWNER {
      PSID Owner;
    } TOKEN_OWNER,*PTOKEN_OWNER;

    typedef struct _TOKEN_PRIMARY_GROUP {
      PSID PrimaryGroup;
    } TOKEN_PRIMARY_GROUP,*PTOKEN_PRIMARY_GROUP;

    typedef struct _TOKEN_DEFAULT_DACL {
      PACL DefaultDacl;
    } TOKEN_DEFAULT_DACL,*PTOKEN_DEFAULT_DACL;

    typedef struct _TOKEN_USER_CLAIMS {
      PCLAIMS_BLOB UserClaims;
    } TOKEN_USER_CLAIMS,*PTOKEN_USER_CLAIMS;

    typedef struct _TOKEN_DEVICE_CLAIMS {
      PCLAIMS_BLOB DeviceClaims;
    } TOKEN_DEVICE_CLAIMS,*PTOKEN_DEVICE_CLAIMS;

    typedef struct _TOKEN_GROUPS_AND_PRIVILEGES {
      DWORD SidCount;
      DWORD SidLength;
      PSID_AND_ATTRIBUTES Sids;
      DWORD RestrictedSidCount;
      DWORD RestrictedSidLength;
      PSID_AND_ATTRIBUTES RestrictedSids;
      DWORD PrivilegeCount;
      DWORD PrivilegeLength;
      PLUID_AND_ATTRIBUTES Privileges;
      LUID AuthenticationId;
    } TOKEN_GROUPS_AND_PRIVILEGES,*PTOKEN_GROUPS_AND_PRIVILEGES;

    typedef struct _TOKEN_LINKED_TOKEN {
      HANDLE LinkedToken;
    } TOKEN_LINKED_TOKEN,*PTOKEN_LINKED_TOKEN;

    typedef struct _TOKEN_ELEVATION {
      DWORD TokenIsElevated;
    } TOKEN_ELEVATION,*PTOKEN_ELEVATION;

    typedef struct _TOKEN_MANDATORY_LABEL {
      SID_AND_ATTRIBUTES Label;
    } TOKEN_MANDATORY_LABEL,*PTOKEN_MANDATORY_LABEL;

#define TOKEN_MANDATORY_POLICY_OFF 0x0
#define TOKEN_MANDATORY_POLICY_NO_WRITE_UP 0x1
#define TOKEN_MANDATORY_POLICY_NEW_PROCESS_MIN 0x2

#define TOKEN_MANDATORY_POLICY_VALID_MASK (TOKEN_MANDATORY_POLICY_NO_WRITE_UP | TOKEN_MANDATORY_POLICY_NEW_PROCESS_MIN)

    typedef struct _TOKEN_MANDATORY_POLICY {
      DWORD Policy;
    } TOKEN_MANDATORY_POLICY,*PTOKEN_MANDATORY_POLICY;

    typedef struct _TOKEN_ACCESS_INFORMATION {
      PSID_AND_ATTRIBUTES_HASH SidHash;
      PSID_AND_ATTRIBUTES_HASH RestrictedSidHash;
      PTOKEN_PRIVILEGES Privileges;
      LUID AuthenticationId;
      TOKEN_TYPE TokenType;
      SECURITY_IMPERSONATION_LEVEL ImpersonationLevel;
      TOKEN_MANDATORY_POLICY MandatoryPolicy;
      DWORD Flags;
      DWORD AppContainerNumber;
      PSID PackageSid;
      PSID_AND_ATTRIBUTES_HASH CapabilitiesHash;
    } TOKEN_ACCESS_INFORMATION,*PTOKEN_ACCESS_INFORMATION;

#define POLICY_AUDIT_SUBCATEGORY_COUNT (56)

    typedef struct _TOKEN_AUDIT_POLICY {
      UCHAR PerUserPolicy[((POLICY_AUDIT_SUBCATEGORY_COUNT) >> 1) + 1];
    } TOKEN_AUDIT_POLICY, *PTOKEN_AUDIT_POLICY;

#define TOKEN_SOURCE_LENGTH 8

    typedef struct _TOKEN_SOURCE {
      CHAR SourceName[TOKEN_SOURCE_LENGTH];
      LUID SourceIdentifier;
    } TOKEN_SOURCE,*PTOKEN_SOURCE;

    typedef struct _TOKEN_STATISTICS {
      LUID TokenId;
      LUID AuthenticationId;
      LARGE_INTEGER ExpirationTime;
      TOKEN_TYPE TokenType;
      SECURITY_IMPERSONATION_LEVEL ImpersonationLevel;
      DWORD DynamicCharged;
      DWORD DynamicAvailable;
      DWORD GroupCount;
      DWORD PrivilegeCount;
      LUID ModifiedId;
    } TOKEN_STATISTICS,*PTOKEN_STATISTICS;

    typedef struct _TOKEN_CONTROL {
      LUID TokenId;
      LUID AuthenticationId;
      LUID ModifiedId;
      TOKEN_SOURCE TokenSource;
    } TOKEN_CONTROL,*PTOKEN_CONTROL;

    typedef struct _TOKEN_ORIGIN {
      LUID OriginatingLogonSession;
    } TOKEN_ORIGIN,*PTOKEN_ORIGIN;

    typedef enum _MANDATORY_LEVEL {
      MandatoryLevelUntrusted = 0,
      MandatoryLevelLow,
      MandatoryLevelMedium,
      MandatoryLevelHigh,
      MandatoryLevelSystem,
      MandatoryLevelSecureProcess,
      MandatoryLevelCount
    } MANDATORY_LEVEL,*PMANDATORY_LEVEL;

    typedef struct _TOKEN_APPCONTAINER_INFORMATION {
      PSID TokenAppContainer;
    } TOKEN_APPCONTAINER_INFORMATION,*PTOKEN_APPCONTAINER_INFORMATION;

#define CLAIM_SECURITY_ATTRIBUTE_TYPE_INVALID 0x00
#define CLAIM_SECURITY_ATTRIBUTE_TYPE_INT64 0x01
#define CLAIM_SECURITY_ATTRIBUTE_TYPE_UINT64 0x02
#define CLAIM_SECURITY_ATTRIBUTE_TYPE_STRING 0x03
#define CLAIM_SECURITY_ATTRIBUTE_TYPE_FQBN 0x04
#define CLAIM_SECURITY_ATTRIBUTE_TYPE_SID 0x05
#define CLAIM_SECURITY_ATTRIBUTE_TYPE_BOOLEAN 0x06

    typedef struct _CLAIM_SECURITY_ATTRIBUTE_FQBN_VALUE {
      DWORD64 Version;
      PWSTR Name;
    } CLAIM_SECURITY_ATTRIBUTE_FQBN_VALUE,*PCLAIM_SECURITY_ATTRIBUTE_FQBN_VALUE;

    typedef struct _CLAIM_SECURITY_ATTRIBUTE_OCTET_STRING_VALUE {
      PVOID pValue;
      DWORD ValueLength;
    } CLAIM_SECURITY_ATTRIBUTE_OCTET_STRING_VALUE, *PCLAIM_SECURITY_ATTRIBUTE_OCTET_STRING_VALUE;

#define CLAIM_SECURITY_ATTRIBUTE_TYPE_OCTET_STRING 0x10
#define CLAIM_SECURITY_ATTRIBUTE_NON_INHERITABLE 0x0001
#define CLAIM_SECURITY_ATTRIBUTE_VALUE_CASE_SENSITIVE 0x0002
#define CLAIM_SECURITY_ATTRIBUTE_USE_FOR_DENY_ONLY 0x0004
#define CLAIM_SECURITY_ATTRIBUTE_DISABLED_BY_DEFAULT 0x0008
#define CLAIM_SECURITY_ATTRIBUTE_DISABLED 0x0010
#define CLAIM_SECURITY_ATTRIBUTE_MANDATORY 0x0020

#define CLAIM_SECURITY_ATTRIBUTE_VALID_FLAGS (CLAIM_SECURITY_ATTRIBUTE_NON_INHERITABLE | CLAIM_SECURITY_ATTRIBUTE_VALUE_CASE_SENSITIVE | CLAIM_SECURITY_ATTRIBUTE_USE_FOR_DENY_ONLY | CLAIM_SECURITY_ATTRIBUTE_DISABLED_BY_DEFAULT | CLAIM_SECURITY_ATTRIBUTE_DISABLED | CLAIM_SECURITY_ATTRIBUTE_MANDATORY)
#define CLAIM_SECURITY_ATTRIBUTE_CUSTOM_FLAGS 0xffff0000

    typedef struct _CLAIM_SECURITY_ATTRIBUTE_V1 {
      PWSTR Name;
      WORD ValueType;
      WORD Reserved;
      DWORD Flags;
      DWORD ValueCount;
      union {
	PLONG64 pInt64;
	PDWORD64 pUint64;
	PWSTR *ppString;
	PCLAIM_SECURITY_ATTRIBUTE_FQBN_VALUE pFqbn;
	PCLAIM_SECURITY_ATTRIBUTE_OCTET_STRING_VALUE pOctetString;
      } Values;
    } CLAIM_SECURITY_ATTRIBUTE_V1,*PCLAIM_SECURITY_ATTRIBUTE_V1;

    typedef struct _CLAIM_SECURITY_ATTRIBUTE_RELATIVE_V1 {
      DWORD Name;
      WORD ValueType;
      WORD Reserved;
      DWORD Flags;
      DWORD ValueCount;
      union {
	DWORD pInt64[ANYSIZE_ARRAY];
	DWORD pUint64[ANYSIZE_ARRAY];
	DWORD ppString[ANYSIZE_ARRAY];
	DWORD pFqbn[ANYSIZE_ARRAY];
	DWORD pOctetString[ANYSIZE_ARRAY];
      } Values;
    } CLAIM_SECURITY_ATTRIBUTE_RELATIVE_V1,*PCLAIM_SECURITY_ATTRIBUTE_RELATIVE_V1;

#define CLAIM_SECURITY_ATTRIBUTES_INFORMATION_VERSION_V1 1

#define CLAIM_SECURITY_ATTRIBUTES_INFORMATION_VERSION CLAIM_SECURITY_ATTRIBUTES_INFORMATION_VERSION_V1

    typedef struct _CLAIM_SECURITY_ATTRIBUTES_INFORMATION {
      WORD Version;
      WORD Reserved;
      DWORD AttributeCount;
      union {
	PCLAIM_SECURITY_ATTRIBUTE_V1 pAttributeV1;
      } Attribute;
    } CLAIM_SECURITY_ATTRIBUTES_INFORMATION,*PCLAIM_SECURITY_ATTRIBUTES_INFORMATION;

#define SECURITY_DYNAMIC_TRACKING (TRUE)
#define SECURITY_STATIC_TRACKING (FALSE)

    typedef BOOLEAN SECURITY_CONTEXT_TRACKING_MODE,*PSECURITY_CONTEXT_TRACKING_MODE;

    typedef struct _SECURITY_QUALITY_OF_SERVICE {
      DWORD Length;
      SECURITY_IMPERSONATION_LEVEL ImpersonationLevel;
      SECURITY_CONTEXT_TRACKING_MODE ContextTrackingMode;
      BOOLEAN EffectiveOnly;
    } SECURITY_QUALITY_OF_SERVICE,*PSECURITY_QUALITY_OF_SERVICE;

    typedef struct _SE_IMPERSONATION_STATE {
      PACCESS_TOKEN Token;
      BOOLEAN CopyOnOpen;
      BOOLEAN EffectiveOnly;
      SECURITY_IMPERSONATION_LEVEL Level;
    } SE_IMPERSONATION_STATE,*PSE_IMPERSONATION_STATE;

#define DISABLE_MAX_PRIVILEGE 0x1
#define SANDBOX_INERT 0x2
#define LUA_TOKEN 0x4
#define WRITE_RESTRICTED 0x8

    typedef DWORD SECURITY_INFORMATION,*PSECURITY_INFORMATION;

#define OWNER_SECURITY_INFORMATION (__MSABI_LONG(0x00000001))
#define GROUP_SECURITY_INFORMATION (__MSABI_LONG(0x00000002))
#define DACL_SECURITY_INFORMATION (__MSABI_LONG(0x00000004))
#define SACL_SECURITY_INFORMATION (__MSABI_LONG(0x00000008))
#define LABEL_SECURITY_INFORMATION (__MSABI_LONG(0x00000010))
#define ATTRIBUTE_SECURITY_INFORMATION (__MSABI_LONG(0x00000020))
#define SCOPE_SECURITY_INFORMATION (__MSABI_LONG(0x00000040))
#define BACKUP_SECURITY_INFORMATION (__MSABI_LONG(0x00010000))

#define PROTECTED_DACL_SECURITY_INFORMATION (__MSABI_LONG(0x80000000))
#define PROTECTED_SACL_SECURITY_INFORMATION (__MSABI_LONG(0x40000000))
#define UNPROTECTED_DACL_SECURITY_INFORMATION (__MSABI_LONG(0x20000000))
#define UNPROTECTED_SACL_SECURITY_INFORMATION (__MSABI_LONG(0x10000000))

    typedef enum _SE_LEARNING_MODE_DATA_TYPE {
      SeLearningModeInvalidType = 0,
      SeLearningModeSettings,
      SeLearningModeMax
    } SE_LEARNING_MODE_DATA_TYPE;

#define SE_LEARNING_MODE_FLAG_PERMISSIVE 0x00000001

    typedef struct _SECURITY_CAPABILITIES {
      PSID AppContainerSid;
      PSID_AND_ATTRIBUTES Capabilities;
      DWORD CapabilityCount;
      DWORD Reserved;
    } SECURITY_CAPABILITIES,*PSECURITY_CAPABILITIES,*LPSECURITY_CAPABILITIES;

#define PROCESS_TERMINATE (0x0001)
#define PROCESS_CREATE_THREAD (0x0002)
#define PROCESS_SET_SESSIONID (0x0004)
#define PROCESS_VM_OPERATION (0x0008)
#define PROCESS_VM_READ (0x0010)
#define PROCESS_VM_WRITE (0x0020)
#define PROCESS_DUP_HANDLE (0x0040)
#define PROCESS_CREATE_PROCESS (0x0080)
#define PROCESS_SET_QUOTA (0x0100)
#define PROCESS_SET_INFORMATION (0x0200)
#define PROCESS_QUERY_INFORMATION (0x0400)
#define PROCESS_SUSPEND_RESUME (0x0800)
#define PROCESS_QUERY_LIMITED_INFORMATION (0x1000)

#if NTDDI_VERSION >= 0x06000000
#define PROCESS_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0xffff)
#else
#define PROCESS_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0xfff)
#endif

#ifdef _WIN64
#define MAXIMUM_PROC_PER_GROUP 64
#else
#define MAXIMUM_PROC_PER_GROUP 32
#endif

#define MAXIMUM_PROCESSORS MAXIMUM_PROC_PER_GROUP

#define THREAD_TERMINATE (0x0001)
#define THREAD_SUSPEND_RESUME (0x0002)
#define THREAD_GET_CONTEXT (0x0008)
#define THREAD_SET_CONTEXT (0x0010)
#define THREAD_SET_INFORMATION (0x0020)
#define THREAD_QUERY_INFORMATION (0x0040)
#define THREAD_SET_THREAD_TOKEN (0x0080)
#define THREAD_IMPERSONATE (0x0100)
#define THREAD_DIRECT_IMPERSONATION (0x0200)
#define THREAD_SET_LIMITED_INFORMATION (0x0400)
#define THREAD_QUERY_LIMITED_INFORMATION (0x0800)

#if NTDDI_VERSION >= 0x06000000
#define THREAD_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0xffff)
#else
#define THREAD_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0x3ff)
#endif

#define JOB_OBJECT_ASSIGN_PROCESS (0x0001)
#define JOB_OBJECT_SET_ATTRIBUTES (0x0002)
#define JOB_OBJECT_QUERY (0x0004)
#define JOB_OBJECT_TERMINATE (0x0008)
#define JOB_OBJECT_SET_SECURITY_ATTRIBUTES (0x0010)
#define JOB_OBJECT_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0x1F)

    typedef struct _JOB_SET_ARRAY {
      HANDLE JobHandle;
      DWORD MemberLevel;
      DWORD Flags;
    } JOB_SET_ARRAY,*PJOB_SET_ARRAY;

#define FLS_MAXIMUM_AVAILABLE 128
#define TLS_MINIMUM_AVAILABLE 64

#ifndef __MINGW_EXCPT_DEFINE_PSDK
    typedef struct _EXCEPTION_REGISTRATION_RECORD {
      __C89_NAMELESS union {
        struct _EXCEPTION_REGISTRATION_RECORD *Next;
        struct _EXCEPTION_REGISTRATION_RECORD *prev;
      };
      __C89_NAMELESS union {
        PEXCEPTION_ROUTINE Handler;
        PEXCEPTION_ROUTINE handler;
      };
    } EXCEPTION_REGISTRATION_RECORD;

    typedef EXCEPTION_REGISTRATION_RECORD *PEXCEPTION_REGISTRATION_RECORD;

    typedef EXCEPTION_REGISTRATION_RECORD EXCEPTION_REGISTRATION;
    typedef PEXCEPTION_REGISTRATION_RECORD PEXCEPTION_REGISTRATION;
#endif

#ifndef _NT_TIB_DEFINED
#define _NT_TIB_DEFINED
    __C89_NAMELESS typedef struct _NT_TIB {
      struct _EXCEPTION_REGISTRATION_RECORD *ExceptionList;
      PVOID StackBase;
      PVOID StackLimit;
      PVOID SubSystemTib;
      __C89_NAMELESS union {
	PVOID FiberData;
	DWORD Version;
      };
      PVOID ArbitraryUserPointer;
      struct _NT_TIB *Self;
    } NT_TIB;
    typedef NT_TIB *PNT_TIB;
#endif /* _NT_TIB_DEFINED */

    __C89_NAMELESS typedef struct _NT_TIB32 {
      DWORD ExceptionList;
      DWORD StackBase;
      DWORD StackLimit;
      DWORD SubSystemTib;
      __C89_NAMELESS union {
	DWORD FiberData;
	DWORD Version;
      };
      DWORD ArbitraryUserPointer;
      DWORD Self;
    } NT_TIB32,*PNT_TIB32;

    __C89_NAMELESS typedef struct _NT_TIB64 {
      DWORD64 ExceptionList;
      DWORD64 StackBase;
      DWORD64 StackLimit;
      DWORD64 SubSystemTib;
      __C89_NAMELESS union {
	DWORD64 FiberData;
	DWORD Version;
      };
      DWORD64 ArbitraryUserPointer;
      DWORD64 Self;
    } NT_TIB64,*PNT_TIB64;

#if !defined(_X86_) && !defined(_IA64_) && !defined(_AMD64_)
#define WX86
#endif

#define THREAD_BASE_PRIORITY_LOWRT 15
#define THREAD_BASE_PRIORITY_MAX 2
#define THREAD_BASE_PRIORITY_MIN (-2)
#define THREAD_BASE_PRIORITY_IDLE (-15)

    typedef struct _UMS_CREATE_THREAD_ATTRIBUTES {
      DWORD UmsVersion;
      PVOID UmsContext;
      PVOID UmsCompletionList;
    } UMS_CREATE_THREAD_ATTRIBUTES,*PUMS_CREATE_THREAD_ATTRIBUTES;

    typedef struct _QUOTA_LIMITS {
      SIZE_T PagedPoolLimit;
      SIZE_T NonPagedPoolLimit;
      SIZE_T MinimumWorkingSetSize;
      SIZE_T MaximumWorkingSetSize;
      SIZE_T PagefileLimit;
      LARGE_INTEGER TimeLimit;
    } QUOTA_LIMITS,*PQUOTA_LIMITS;

#define QUOTA_LIMITS_HARDWS_MIN_ENABLE 0x00000001
#define QUOTA_LIMITS_HARDWS_MIN_DISABLE 0x00000002
#define QUOTA_LIMITS_HARDWS_MAX_ENABLE 0x00000004
#define QUOTA_LIMITS_HARDWS_MAX_DISABLE 0x00000008
#define QUOTA_LIMITS_USE_DEFAULT_LIMITS 0x00000010

    typedef union _RATE_QUOTA_LIMIT {
      DWORD RateData;
      __C89_NAMELESS struct {
        DWORD RatePercent : 7;
        DWORD Reserved0   : 25;
      } DUMMYSTRUCTNAME;
    } RATE_QUOTA_LIMIT, *PRATE_QUOTA_LIMIT;

    typedef struct _QUOTA_LIMITS_EX {
      SIZE_T PagedPoolLimit;
      SIZE_T NonPagedPoolLimit;
      SIZE_T MinimumWorkingSetSize;
      SIZE_T MaximumWorkingSetSize;
      SIZE_T PagefileLimit;
      LARGE_INTEGER TimeLimit;
      SIZE_T WorkingSetLimit;
      SIZE_T Reserved2;
      SIZE_T Reserved3;
      SIZE_T Reserved4;
      DWORD Flags;
      RATE_QUOTA_LIMIT CpuRateLimit;
    } QUOTA_LIMITS_EX,*PQUOTA_LIMITS_EX;

    typedef struct _IO_COUNTERS {
      ULONGLONG ReadOperationCount;
      ULONGLONG WriteOperationCount;
      ULONGLONG OtherOperationCount;
      ULONGLONG ReadTransferCount;
      ULONGLONG WriteTransferCount;
      ULONGLONG OtherTransferCount;
    } IO_COUNTERS;
    typedef IO_COUNTERS *PIO_COUNTERS;

#define MAX_HW_COUNTERS 16
#define THREAD_PROFILING_FLAG_DISPATCH 0x1

    typedef enum _HARDWARE_COUNTER_TYPE {
      PMCCounter,
      MaxHardwareCounterType
    } HARDWARE_COUNTER_TYPE, *PHARDWARE_COUNTER_TYPE;

    typedef enum _PROCESS_MITIGATION_POLICY {
      ProcessDEPPolicy,
      ProcessASLRPolicy,
      ProcessDynamicCodePolicy,
      ProcessStrictHandleCheckPolicy,
      ProcessSystemCallDisablePolicy,
      ProcessMitigationOptionsMask,
      ProcessExtensionPointDisablePolicy,
      ProcessControlFlowGuardPolicy,
      ProcessSignaturePolicy,
      ProcessFontDisablePolicy,
      ProcessImageLoadPolicy,
      ProcessSystemCallFilterPolicy,
      ProcessPayloadRestrictionPolicy,
      ProcessChildProcessPolicy,
      ProcessSideChannelIsolationPolicy,
      MaxProcessMitigationPolicy
    } PROCESS_MITIGATION_POLICY,*PPROCESS_MITIGATION_POLICY;

    typedef struct _PROCESS_MITIGATION_ASLR_POLICY {
      __C89_NAMELESS union {
        DWORD Flags;
        __C89_NAMELESS struct {
          DWORD EnableBottomUpRandomization : 1;
          DWORD EnableForceRelocateImages : 1;
          DWORD EnableHighEntropy : 1;
          DWORD DisallowStrippedImages : 1;
          DWORD ReservedFlags : 28;
        };
      };
    } PROCESS_MITIGATION_ASLR_POLICY,*PPROCESS_MITIGATION_ASLR_POLICY;

    typedef struct _PROCESS_MITIGATION_DEP_POLICY {
      __C89_NAMELESS union {
        DWORD Flags;
        __C89_NAMELESS struct {
          DWORD Enable : 1;
          DWORD DisableAtlThunkEmulation : 1;
          DWORD ReservedFlags : 30;
        };
      };
      BOOLEAN Permanent;
    } PROCESS_MITIGATION_DEP_POLICY,*PPROCESS_MITIGATION_DEP_POLICY;

    typedef struct _PROCESS_MITIGATION_STRICT_HANDLE_CHECK_POLICY {
      __C89_NAMELESS union {
        DWORD Flags;
        __C89_NAMELESS struct {
          DWORD RaiseExceptionOnInvalidHandleReference : 1;
          DWORD HandleExceptionsPermanentlyEnabled : 1;
          DWORD ReservedFlags : 30;
        };
      };
    } PROCESS_MITIGATION_STRICT_HANDLE_CHECK_POLICY,*PPROCESS_MITIGATION_STRICT_HANDLE_CHECK_POLICY;

    typedef struct _PROCESS_MITIGATION_SYSTEM_CALL_DISABLE_POLICY {
      __C89_NAMELESS union {
        DWORD Flags;
        __C89_NAMELESS struct {
          DWORD DisallowWin32kSystemCalls : 1;
          DWORD ReservedFlags : 31;
        };
      };
    } PROCESS_MITIGATION_SYSTEM_CALL_DISABLE_POLICY,*PPROCESS_MITIGATION_SYSTEM_CALL_DISABLE_POLICY;

    typedef struct _PROCESS_MITIGATION_EXTENSION_POINT_DISABLE_POLICY {
      __C89_NAMELESS union {
        DWORD Flags;
        __C89_NAMELESS struct {
          DWORD DisableExtensionPoints : 1;
          DWORD ReservedFlags : 31;
        };
      };
    } PROCESS_MITIGATION_EXTENSION_POINT_DISABLE_POLICY,*PPROCESS_MITIGATION_EXTENSION_POINT_DISABLE_POLICY;

    typedef struct _PROCESS_MITIGATION_CONTROL_FLOW_GUARD_POLICY {
      __C89_NAMELESS union {
        DWORD  Flags;
        __C89_NAMELESS struct {
          DWORD EnableControlFlowGuard  :1;
          DWORD EnableExportSuppression  :1;
          DWORD StrictMode  :1;
          DWORD ReservedFlags  :29;
        };
      };
    } PROCESS_MITIGATION_CONTROL_FLOW_GUARD_POLICY, *PPROCESS_MITIGATION_CONTROL_FLOW_GUARD_POLICY;

    typedef struct _PROCESS_MITIGATION_BINARY_SIGNATURE_POLICY {
      __C89_NAMELESS union {
        DWORD  Flags;
        __C89_NAMELESS struct {
          DWORD MicrosoftSignedOnly  :1;
          DWORD StoreSignedOnly  :1;
          DWORD MitigationOptIn  :1;
          DWORD ReservedFlags  :29;
        };
      };
    } PROCESS_MITIGATION_BINARY_SIGNATURE_POLICY, *PPROCESS_MITIGATION_BINARY_SIGNATURE_POLICY;

    typedef struct _PROCESS_MITIGATION_DYNAMIC_CODE_POLICY {
      __C89_NAMELESS union {
        DWORD  Flags;
        __C89_NAMELESS struct {
          DWORD ProhibitDynamicCode  :1;
          DWORD AllowThreadOptOut  :1;
          DWORD AllowRemoteDowngrade  :1;
          DWORD ReservedFlags  :30;
        };
      };
    } PROCESS_MITIGATION_DYNAMIC_CODE_POLICY, *PPROCESS_MITIGATION_DYNAMIC_CODE_POLICY;

    typedef struct _PROCESS_MITIGATION_FONT_DISABLE_POLICY {
      __C89_NAMELESS union {
        DWORD  Flags;
        __C89_NAMELESS struct {
          DWORD DisableNonSystemFonts  :1;
          DWORD AuditNonSystemFontLoading  :1;
          DWORD ReservedFlags  :30;
        };
      };
    } PROCESS_MITIGATION_FONT_DISABLE_POLICY, *PPROCESS_MITIGATION_FONT_DISABLE_POLICY;

    typedef struct _PROCESS_MITIGATION_IMAGE_LOAD_POLICY {
      __C89_NAMELESS union {
        DWORD  Flags;
        __C89_NAMELESS struct {
          DWORD NoRemoteImages  :1;
          DWORD NoLowMandatoryLabelImages  :1;
          DWORD PreferSystem32Images  :1;
          DWORD ReservedFlags  :29;
        };
      };
    } PROCESS_MITIGATION_IMAGE_LOAD_POLICY, *PPROCESS_MITIGATION_IMAGE_LOAD_POLICY;

    typedef struct _PROCESS_MITIGATION_SYSTEM_CALL_FILTER_POLICY {
      __C89_NAMELESS union {
        DWORD Flags;
        __C89_NAMELESS struct {
          DWORD FilterId  :4;
          DWORD ReservedFlags  :28;
        };
      };
    } PROCESS_MITIGATION_SYSTEM_CALL_FILTER_POLICY, *PPROCESS_MITIGATION_SYSTEM_CALL_FILTER_POLICY;

    typedef struct _PROCESS_MITIGATION_PAYLOAD_RESTRICTION_POLICY {
      __C89_NAMELESS union {
        DWORD Flags;
        __C89_NAMELESS struct {
          DWORD EnableExportAddressFilter  :1;
          DWORD AuditExportAddressFilter  :1;
          DWORD EnableExportAddressFilterPlus  :1;
          DWORD AuditExportAddressFilterPlus  :1;
          DWORD EnableImportAddressFilter  :1;
          DWORD AuditImportAddressFilter  :1;
          DWORD EnableRopStackPivot  :1;
          DWORD AuditRopStackPivot  :1;
          DWORD EnableRopCallerCheck  :1;
          DWORD AuditRopCallerCheck  :1;
          DWORD EnableRopSimExec  :1;
          DWORD AuditRopSimExec  :1;
          DWORD ReservedFlags  :20;
        };
      };
    } PROCESS_MITIGATION_PAYLOAD_RESTRICTION_POLICY, *PPROCESS_MITIGATION_PAYLOAD_RESTRICTION_POLICY;

    typedef struct _PROCESS_MITIGATION_CHILD_PROCESS_POLICY {
      __C89_NAMELESS union {
        DWORD Flags;
        __C89_NAMELESS struct {
          DWORD NoChildProcessCreation  :1;
          DWORD AuditNoChildProcessCreation  :1;
          DWORD AllowSecureProcessCreation  :1;
          DWORD ReservedFlags  :29;
        };
      };
    } PROCESS_MITIGATION_CHILD_PROCESS_POLICY, *PPROCESS_MITIGATION_CHILD_PROCESS_POLICY;

    typedef struct _PROCESS_MITIGATION_SIDE_CHANNEL_ISOLATION_POLICY {
      __C89_NAMELESS union {
        DWORD Flags;
        __C89_NAMELESS struct {
          DWORD SmtBranchTargetIsolation  :1;
          DWORD IsolateSecurityDomain  :1;
          DWORD DisablePageCombine  :1;
          DWORD SpeculativeStoreBypassDisable  :1;
          DWORD ReservedFlags  :28;
        };
      };
    } PROCESS_MITIGATION_SIDE_CHANNEL_ISOLATION_POLICY, *PPROCESS_MITIGATION_SIDE_CHANNEL_ISOLATION_POLICY;

    typedef struct _JOBOBJECT_BASIC_ACCOUNTING_INFORMATION {
      LARGE_INTEGER TotalUserTime;
      LARGE_INTEGER TotalKernelTime;
      LARGE_INTEGER ThisPeriodTotalUserTime;
      LARGE_INTEGER ThisPeriodTotalKernelTime;
      DWORD TotalPageFaultCount;
      DWORD TotalProcesses;
      DWORD ActiveProcesses;
      DWORD TotalTerminatedProcesses;
    } JOBOBJECT_BASIC_ACCOUNTING_INFORMATION,*PJOBOBJECT_BASIC_ACCOUNTING_INFORMATION;

    typedef struct _JOBOBJECT_BASIC_LIMIT_INFORMATION {
      LARGE_INTEGER PerProcessUserTimeLimit;
      LARGE_INTEGER PerJobUserTimeLimit;
      DWORD LimitFlags;
      SIZE_T MinimumWorkingSetSize;
      SIZE_T MaximumWorkingSetSize;
      DWORD ActiveProcessLimit;
      ULONG_PTR Affinity;
      DWORD PriorityClass;
      DWORD SchedulingClass;
    } JOBOBJECT_BASIC_LIMIT_INFORMATION,*PJOBOBJECT_BASIC_LIMIT_INFORMATION;

    typedef struct _JOBOBJECT_EXTENDED_LIMIT_INFORMATION {
      JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
      IO_COUNTERS IoInfo;
      SIZE_T ProcessMemoryLimit;
      SIZE_T JobMemoryLimit;
      SIZE_T PeakProcessMemoryUsed;
      SIZE_T PeakJobMemoryUsed;
    } JOBOBJECT_EXTENDED_LIMIT_INFORMATION,*PJOBOBJECT_EXTENDED_LIMIT_INFORMATION;

    typedef struct _JOBOBJECT_BASIC_PROCESS_ID_LIST {
      DWORD NumberOfAssignedProcesses;
      DWORD NumberOfProcessIdsInList;
      ULONG_PTR ProcessIdList[1];
    } JOBOBJECT_BASIC_PROCESS_ID_LIST,*PJOBOBJECT_BASIC_PROCESS_ID_LIST;

    typedef struct _JOBOBJECT_BASIC_UI_RESTRICTIONS {
      DWORD UIRestrictionsClass;
    } JOBOBJECT_BASIC_UI_RESTRICTIONS,*PJOBOBJECT_BASIC_UI_RESTRICTIONS;

    typedef struct _JOBOBJECT_SECURITY_LIMIT_INFORMATION {
      DWORD SecurityLimitFlags;
      HANDLE JobToken;
      PTOKEN_GROUPS SidsToDisable;
      PTOKEN_PRIVILEGES PrivilegesToDelete;
      PTOKEN_GROUPS RestrictedSids;
    } JOBOBJECT_SECURITY_LIMIT_INFORMATION,*PJOBOBJECT_SECURITY_LIMIT_INFORMATION;

    typedef struct _JOBOBJECT_END_OF_JOB_TIME_INFORMATION {
      DWORD EndOfJobTimeAction;
    } JOBOBJECT_END_OF_JOB_TIME_INFORMATION,*PJOBOBJECT_END_OF_JOB_TIME_INFORMATION;

    typedef struct _JOBOBJECT_ASSOCIATE_COMPLETION_PORT {
      PVOID CompletionKey;
      HANDLE CompletionPort;
    } JOBOBJECT_ASSOCIATE_COMPLETION_PORT,*PJOBOBJECT_ASSOCIATE_COMPLETION_PORT;

    typedef struct _JOBOBJECT_BASIC_AND_IO_ACCOUNTING_INFORMATION {
      JOBOBJECT_BASIC_ACCOUNTING_INFORMATION BasicInfo;
      IO_COUNTERS IoInfo;
    } JOBOBJECT_BASIC_AND_IO_ACCOUNTING_INFORMATION,*PJOBOBJECT_BASIC_AND_IO_ACCOUNTING_INFORMATION;

    typedef struct _JOBOBJECT_JOBSET_INFORMATION {
      DWORD MemberLevel;
    } JOBOBJECT_JOBSET_INFORMATION,*PJOBOBJECT_JOBSET_INFORMATION;

    typedef enum _JOBOBJECT_RATE_CONTROL_TOLERANCE {
      ToleranceLow = 1,
      ToleranceMedium,
      ToleranceHigh
    } JOBOBJECT_RATE_CONTROL_TOLERANCE;

    typedef enum _JOBOBJECT_RATE_CONTROL_TOLERANCE_INTERVAL {
      ToleranceIntervalShort = 1,
      ToleranceIntervalMedium,
      ToleranceIntervalLong
    } JOBOBJECT_RATE_CONTROL_TOLERANCE_INTERVAL;

    typedef struct _JOBOBJECT_NOTIFICATION_LIMIT_INFORMATION {
      DWORD64 IoReadBytesLimit;
      DWORD64 IoWriteBytesLimit;
      LARGE_INTEGER PerJobUserTimeLimit;
      DWORD64 JobMemoryLimit;
      JOBOBJECT_RATE_CONTROL_TOLERANCE RateControlTolerance;
      JOBOBJECT_RATE_CONTROL_TOLERANCE_INTERVAL RateControlToleranceInterval;
      DWORD LimitFlags;
    } JOBOBJECT_NOTIFICATION_LIMIT_INFORMATION,*PJOBOBJECT_NOTIFICATION_LIMIT_INFORMATION;

    typedef struct _JOBOBJECT_LIMIT_VIOLATION_INFORMATION {
      DWORD LimitFlags;
      DWORD ViolationLimitFlags;
      DWORD64 IoReadBytes;
      DWORD64 IoReadBytesLimit;
      DWORD64 IoWriteBytes;
      DWORD64 IoWriteBytesLimit;
      LARGE_INTEGER PerJobUserTime;
      LARGE_INTEGER PerJobUserTimeLimit;
      DWORD64 JobMemory;
      DWORD64 JobMemoryLimit;
      JOBOBJECT_RATE_CONTROL_TOLERANCE RateControlTolerance;
      JOBOBJECT_RATE_CONTROL_TOLERANCE_INTERVAL RateControlToleranceLimit;
    } JOBOBJECT_LIMIT_VIOLATION_INFORMATION,*PJOBOBJECT_LIMIT_VIOLATION_INFORMATION;

    typedef struct _JOBOBJECT_CPU_RATE_CONTROL_INFORMATION {
      DWORD ControlFlags;
      __C89_NAMELESS union {
	DWORD CpuRate;
	DWORD Weight;
      };
    } JOBOBJECT_CPU_RATE_CONTROL_INFORMATION,*PJOBOBJECT_CPU_RATE_CONTROL_INFORMATION;

#define JOB_OBJECT_TERMINATE_AT_END_OF_JOB 0
#define JOB_OBJECT_POST_AT_END_OF_JOB 1

#define JOB_OBJECT_MSG_END_OF_JOB_TIME 1
#define JOB_OBJECT_MSG_END_OF_PROCESS_TIME 2
#define JOB_OBJECT_MSG_ACTIVE_PROCESS_LIMIT 3
#define JOB_OBJECT_MSG_ACTIVE_PROCESS_ZERO 4
#define JOB_OBJECT_MSG_NEW_PROCESS 6
#define JOB_OBJECT_MSG_EXIT_PROCESS 7
#define JOB_OBJECT_MSG_ABNORMAL_EXIT_PROCESS 8
#define JOB_OBJECT_MSG_PROCESS_MEMORY_LIMIT 9
#define JOB_OBJECT_MSG_JOB_MEMORY_LIMIT 10
#define JOB_OBJECT_MSG_NOTIFICATION_LIMIT 11
#define JOB_OBJECT_MSG_JOB_CYCLE_TIME_LIMIT 12

#define JOB_OBJECT_MSG_MINIMUM 1
#define JOB_OBJECT_MSG_MAXIMUM 12

#define JOB_OBJECT_LIMIT_WORKINGSET 0x00000001
#define JOB_OBJECT_LIMIT_PROCESS_TIME 0x00000002
#define JOB_OBJECT_LIMIT_JOB_TIME 0x00000004
#define JOB_OBJECT_LIMIT_ACTIVE_PROCESS 0x00000008
#define JOB_OBJECT_LIMIT_AFFINITY 0x00000010
#define JOB_OBJECT_LIMIT_PRIORITY_CLASS 0x00000020
#define JOB_OBJECT_LIMIT_PRESERVE_JOB_TIME 0x00000040
#define JOB_OBJECT_LIMIT_SCHEDULING_CLASS 0x00000080

#define JOB_OBJECT_LIMIT_PROCESS_MEMORY 0x00000100
#define JOB_OBJECT_LIMIT_JOB_MEMORY 0x00000200
#define JOB_OBJECT_LIMIT_DIE_ON_UNHANDLED_EXCEPTION 0x00000400
#define JOB_OBJECT_LIMIT_BREAKAWAY_OK 0x00000800
#define JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK 0x00001000
#define JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE 0x00002000

#define JOB_OBJECT_LIMIT_SUBSET_AFFINITY 0x00004000
#define JOB_OBJECT_LIMIT_RESERVED3 0x00008000
#define JOB_OBJECT_LIMIT_JOB_READ_BYTES 0x00010000
#define JOB_OBJECT_LIMIT_JOB_WRITE_BYTES 0x00020000
#define JOB_OBJECT_LIMIT_RATE_CONTROL 0x00040000

#define JOB_OBJECT_LIMIT_RESERVED3 0x00008000
#define JOB_OBJECT_LIMIT_RESERVED4 0x00010000
#define JOB_OBJECT_LIMIT_RESERVED5 0x00020000
#define JOB_OBJECT_LIMIT_RESERVED6 0x00040000

#define JOB_OBJECT_LIMIT_VALID_FLAGS 0x0007ffff

#define JOB_OBJECT_BASIC_LIMIT_VALID_FLAGS 0x000000ff
#define JOB_OBJECT_EXTENDED_LIMIT_VALID_FLAGS 0x00007fff
#define JOB_OBJECT_RESERVED_LIMIT_VALID_FLAGS 0x0007ffff
#define JOB_OBJECT_NOTIFICATION_LIMIT_VALID_FLAGS 0x00070204

#define JOB_OBJECT_UILIMIT_NONE 0x00000000

#define JOB_OBJECT_UILIMIT_HANDLES 0x00000001
#define JOB_OBJECT_UILIMIT_READCLIPBOARD 0x00000002
#define JOB_OBJECT_UILIMIT_WRITECLIPBOARD 0x00000004
#define JOB_OBJECT_UILIMIT_SYSTEMPARAMETERS 0x00000008
#define JOB_OBJECT_UILIMIT_DISPLAYSETTINGS 0x00000010
#define JOB_OBJECT_UILIMIT_GLOBALATOMS 0x00000020
#define JOB_OBJECT_UILIMIT_DESKTOP 0x00000040
#define JOB_OBJECT_UILIMIT_EXITWINDOWS 0x00000080

#define JOB_OBJECT_UILIMIT_ALL 0x000000FF

#define JOB_OBJECT_UI_VALID_FLAGS 0x000000FF

#define JOB_OBJECT_SECURITY_NO_ADMIN 0x00000001
#define JOB_OBJECT_SECURITY_RESTRICTED_TOKEN 0x00000002
#define JOB_OBJECT_SECURITY_ONLY_TOKEN 0x00000004
#define JOB_OBJECT_SECURITY_FILTER_TOKENS 0x00000008

#define JOB_OBJECT_SECURITY_VALID_FLAGS 0x0000000f

#define JOB_OBJECT_CPU_RATE_CONTROL_ENABLE 0x1
#define JOB_OBJECT_CPU_RATE_CONTROL_WEIGHT_BASED 0x2
#define JOB_OBJECT_CPU_RATE_CONTROL_HARD_CAP 0x4
#define JOB_OBJECT_CPU_RATE_CONTROL_NOTIFY 0x8
#define JOB_OBJECT_CPU_RATE_CONTROL_VALID_FLAGS 0xf

    typedef enum _JOBOBJECTINFOCLASS {
      JobObjectBasicAccountingInformation = 1, JobObjectBasicLimitInformation,
      JobObjectBasicProcessIdList, JobObjectBasicUIRestrictions,
      JobObjectSecurityLimitInformation, JobObjectEndOfJobTimeInformation,
      JobObjectAssociateCompletionPortInformation, JobObjectBasicAndIoAccountingInformation,
      JobObjectExtendedLimitInformation, JobObjectJobSetInformation,
      JobObjectGroupInformation,
      JobObjectNotificationLimitInformation,
      JobObjectLimitViolationInformation,
      JobObjectGroupInformationEx,
      JobObjectCpuRateControlInformation,
      JobObjectCompletionFilter,
      JobObjectCompletionCounter,
      JobObjectReserved1Information = 18,
      JobObjectReserved2Information,
      JobObjectReserved3Information,
      JobObjectReserved4Information,
      JobObjectReserved5Information,
      JobObjectReserved6Information,
      JobObjectReserved7Information,
      JobObjectReserved8Information,
      MaxJobObjectInfoClass
    } JOBOBJECTINFOCLASS;

    typedef enum _FIRMWARE_TYPE {
      FirmwareTypeUnknown,
      FirmwareTypeBios,
      FirmwareTypeUefi,
      FirmwareTypeMax
    } FIRMWARE_TYPE,*PFIRMWARE_TYPE;

#define EVENT_MODIFY_STATE 0x0002
#define EVENT_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED|SYNCHRONIZE|0x3)

#define MUTANT_QUERY_STATE 0x0001

#define MUTANT_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED|SYNCHRONIZE| MUTANT_QUERY_STATE)
#define SEMAPHORE_MODIFY_STATE 0x0002
#define SEMAPHORE_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED|SYNCHRONIZE|0x3)

#define TIMER_QUERY_STATE 0x0001
#define TIMER_MODIFY_STATE 0x0002

#define TIMER_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED|SYNCHRONIZE| TIMER_QUERY_STATE|TIMER_MODIFY_STATE)

#define TIME_ZONE_ID_UNKNOWN 0
#define TIME_ZONE_ID_STANDARD 1
#define TIME_ZONE_ID_DAYLIGHT 2

    typedef enum _LOGICAL_PROCESSOR_RELATIONSHIP {
      RelationProcessorCore,RelationNumaNode,RelationCache,
      RelationProcessorPackage,RelationGroup,RelationAll=0xffff
    } LOGICAL_PROCESSOR_RELATIONSHIP;

#define LTP_PC_SMT 0x1

    typedef enum _PROCESSOR_CACHE_TYPE {
      CacheUnified,CacheInstruction,CacheData,CacheTrace
    } PROCESSOR_CACHE_TYPE;

#define CACHE_FULLY_ASSOCIATIVE 0xFF

    typedef struct _CACHE_DESCRIPTOR {
      BYTE Level;
      BYTE Associativity;
      WORD LineSize;
      DWORD Size;
      PROCESSOR_CACHE_TYPE Type;
    } CACHE_DESCRIPTOR,*PCACHE_DESCRIPTOR;

    typedef struct _SYSTEM_LOGICAL_PROCESSOR_INFORMATION {
      ULONG_PTR ProcessorMask;
      LOGICAL_PROCESSOR_RELATIONSHIP Relationship;
      __C89_NAMELESS union {
	struct {
	  BYTE Flags;
	} ProcessorCore;
	struct {
	  DWORD NodeNumber;
	} NumaNode;
	CACHE_DESCRIPTOR Cache;
	ULONGLONG Reserved[2];
      } DUMMYUNIONNAME;
    } SYSTEM_LOGICAL_PROCESSOR_INFORMATION,*PSYSTEM_LOGICAL_PROCESSOR_INFORMATION;

    typedef struct _PROCESSOR_RELATIONSHIP {
      BYTE Flags;
      BYTE Reserved[21];
      WORD GroupCount;
      GROUP_AFFINITY GroupMask[ANYSIZE_ARRAY];
    } PROCESSOR_RELATIONSHIP,*PPROCESSOR_RELATIONSHIP;

    typedef struct _NUMA_NODE_RELATIONSHIP {
      DWORD NodeNumber;
      BYTE Reserved[20];
      GROUP_AFFINITY GroupMask;
    } NUMA_NODE_RELATIONSHIP,*PNUMA_NODE_RELATIONSHIP;

    typedef struct _CACHE_RELATIONSHIP {
      BYTE Level;
      BYTE Associativity;
      WORD LineSize;
      DWORD CacheSize;
      PROCESSOR_CACHE_TYPE Type;
      BYTE Reserved[20];
      GROUP_AFFINITY GroupMask;
    } CACHE_RELATIONSHIP,*PCACHE_RELATIONSHIP;

    typedef struct _PROCESSOR_GROUP_INFO {
      BYTE MaximumProcessorCount;
      BYTE ActiveProcessorCount;
      BYTE Reserved[38];
      KAFFINITY ActiveProcessorMask;
    } PROCESSOR_GROUP_INFO,*PPROCESSOR_GROUP_INFO;

    typedef struct _GROUP_RELATIONSHIP {
      WORD MaximumGroupCount;
      WORD ActiveGroupCount;
      BYTE Reserved[20];
      PROCESSOR_GROUP_INFO GroupInfo[ANYSIZE_ARRAY];
    } GROUP_RELATIONSHIP,*PGROUP_RELATIONSHIP;

    struct _SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX {
      LOGICAL_PROCESSOR_RELATIONSHIP Relationship;
      DWORD Size;
      __C89_NAMELESS union {
	PROCESSOR_RELATIONSHIP Processor;
	NUMA_NODE_RELATIONSHIP NumaNode;
	CACHE_RELATIONSHIP Cache;
	GROUP_RELATIONSHIP Group;
      } DUMMYUNIONNAME;
    };

    typedef struct _SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX,*PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX;

    typedef struct _SYSTEM_PROCESSOR_CYCLE_TIME_INFORMATION {
      DWORD64 CycleTime;
    } SYSTEM_PROCESSOR_CYCLE_TIME_INFORMATION,*PSYSTEM_PROCESSOR_CYCLE_TIME_INFORMATION;

#define PROCESSOR_INTEL_386 386
#define PROCESSOR_INTEL_486 486
#define PROCESSOR_INTEL_PENTIUM 586
#define PROCESSOR_INTEL_IA64 2200
#define PROCESSOR_AMD_X8664 8664
#define PROCESSOR_MIPS_R4000 4000
#define PROCESSOR_ALPHA_21064 21064
#define PROCESSOR_PPC_601 601
#define PROCESSOR_PPC_603 603
#define PROCESSOR_PPC_604 604
#define PROCESSOR_PPC_620 620
#define PROCESSOR_HITACHI_SH3 10003
#define PROCESSOR_HITACHI_SH3E 10004
#define PROCESSOR_HITACHI_SH4 10005
#define PROCESSOR_MOTOROLA_821 821
#define PROCESSOR_SHx_SH3 103
#define PROCESSOR_SHx_SH4 104
#define PROCESSOR_STRONGARM 2577
#define PROCESSOR_ARM720 1824
#define PROCESSOR_ARM820 2080
#define PROCESSOR_ARM920 2336
#define PROCESSOR_ARM_7TDMI 70001
#define PROCESSOR_OPTIL 0x494f

#define PROCESSOR_ARCHITECTURE_INTEL 0
#define PROCESSOR_ARCHITECTURE_MIPS 1
#define PROCESSOR_ARCHITECTURE_ALPHA 2
#define PROCESSOR_ARCHITECTURE_PPC 3
#define PROCESSOR_ARCHITECTURE_SHX 4
#define PROCESSOR_ARCHITECTURE_ARM 5
#define PROCESSOR_ARCHITECTURE_IA64 6
#define PROCESSOR_ARCHITECTURE_ALPHA64 7
#define PROCESSOR_ARCHITECTURE_MSIL 8
#define PROCESSOR_ARCHITECTURE_AMD64 9
#define PROCESSOR_ARCHITECTURE_IA32_ON_WIN64 10
#define PROCESSOR_ARCHITECTURE_NEUTRAL 11
#define PROCESSOR_ARCHITECTURE_ARM64 12
#define PROCESSOR_ARCHITECTURE_ARM32_ON_WIN64 13
#define PROCESSOR_ARCHITECTURE_IA32_ON_ARM64 14

#define PROCESSOR_ARCHITECTURE_UNKNOWN 0xffff

#define PF_FLOATING_POINT_PRECISION_ERRATA 0
#define PF_FLOATING_POINT_EMULATED 1
#define PF_COMPARE_EXCHANGE_DOUBLE 2
#define PF_MMX_INSTRUCTIONS_AVAILABLE 3
#define PF_PPC_MOVEMEM_64BIT_OK 4
#define PF_ALPHA_BYTE_INSTRUCTIONS 5
#define PF_XMMI_INSTRUCTIONS_AVAILABLE 6
#define PF_3DNOW_INSTRUCTIONS_AVAILABLE 7
#define PF_RDTSC_INSTRUCTION_AVAILABLE 8
#define PF_PAE_ENABLED 9
#define PF_XMMI64_INSTRUCTIONS_AVAILABLE 10
#define PF_SSE_DAZ_MODE_AVAILABLE 11
#define PF_NX_ENABLED 12
#define PF_SSE3_INSTRUCTIONS_AVAILABLE 13
#define PF_COMPARE_EXCHANGE128 14
#define PF_COMPARE64_EXCHANGE128 15
#define PF_CHANNELS_ENABLED 16
#define PF_XSAVE_ENABLED 17
#define PF_ARM_VFP_32_REGISTERS_AVAILABLE 18
#define PF_ARM_NEON_INSTRUCTIONS_AVAILABLE 19
#define PF_SECOND_LEVEL_ADDRESS_TRANSLATION 20
#define PF_VIRT_FIRMWARE_ENABLED 21
#define PF_RDWRFSGSBASE_AVAILABLE 22
#define PF_FASTFAIL_AVAILABLE 23
#define PF_ARM_DIVIDE_INSTRUCTION_AVAILABLE 24
#define PF_ARM_64BIT_LOADSTORE_ATOMIC 25
#define PF_ARM_EXTERNAL_CACHE_AVAILABLE 26
#define PF_ARM_FMAC_INSTRUCTIONS_AVAILABLE 27
#define PF_RDRAND_INSTRUCTION_AVAILABLE 28
#define PF_ARM_V8_INSTRUCTIONS_AVAILABLE 29
#define PF_ARM_V8_CRYPTO_INSTRUCTIONS_AVAILABLE 30
#define PF_ARM_V8_CRC32_INSTRUCTIONS_AVAILABLE 31
#define PF_RDTSCP_INSTRUCTION_AVAILABLE 32
#define PF_RDPID_INSTRUCTION_AVAILABLE 33

#define XSTATE_LEGACY_FLOATING_POINT (0)
#define XSTATE_LEGACY_SSE (1)
#define XSTATE_GSSE (2)
#define XSTATE_AVX (XSTATE_GSSE)

#define XSTATE_MASK_LEGACY_FLOATING_POINT (1ULL << (XSTATE_LEGACY_FLOATING_POINT))
#define XSTATE_MASK_LEGACY_SSE (1ULL << (XSTATE_LEGACY_SSE))
#define XSTATE_MASK_LEGACY (XSTATE_MASK_LEGACY_FLOATING_POINT | XSTATE_MASK_LEGACY_SSE)
#define XSTATE_MASK_GSSE (1LLU << (XSTATE_GSSE))
#define XSTATE_MASK_AVX (XSTATE_MASK_GSSE)

#define MAXIMUM_XSTATE_FEATURES (64)

    typedef struct _XSTATE_FEATURE {
      DWORD Offset;
      DWORD Size;
    } XSTATE_FEATURE,*PXSTATE_FEATURE;

    typedef struct _XSTATE_CONFIGURATION {
      DWORD64 EnabledFeatures;
      DWORD64 EnabledVolatileFeatures;
      DWORD Size;
      DWORD OptimizedSave : 1;
      XSTATE_FEATURE Features[MAXIMUM_XSTATE_FEATURES];
    } XSTATE_CONFIGURATION,*PXSTATE_CONFIGURATION;

    typedef struct _MEMORY_BASIC_INFORMATION {
      PVOID BaseAddress;
      PVOID AllocationBase;
      DWORD AllocationProtect;
      SIZE_T RegionSize;
      DWORD State;
      DWORD Protect;
      DWORD Type;
    } MEMORY_BASIC_INFORMATION,*PMEMORY_BASIC_INFORMATION;

    typedef struct _MEMORY_BASIC_INFORMATION32 {
      DWORD BaseAddress;
      DWORD AllocationBase;
      DWORD AllocationProtect;
      DWORD RegionSize;
      DWORD State;
      DWORD Protect;
      DWORD Type;
    } MEMORY_BASIC_INFORMATION32,*PMEMORY_BASIC_INFORMATION32;

    typedef struct DECLSPEC_ALIGN(16) _MEMORY_BASIC_INFORMATION64 {
      ULONGLONG BaseAddress;
      ULONGLONG AllocationBase;
      DWORD AllocationProtect;
      DWORD __alignment1;
      ULONGLONG RegionSize;
      DWORD State;
      DWORD Protect;
      DWORD Type;
      DWORD __alignment2;
    } MEMORY_BASIC_INFORMATION64,*PMEMORY_BASIC_INFORMATION64;

#define CFG_CALL_TARGET_VALID 0x01
#define CFG_CALL_TARGET_PROCESSED 0x02
#define CFG_CALL_TARGET_CONVERT_EXPORT_SUPPRESSED_TO_VALID 0x04

  typedef struct _CFG_CALL_TARGET_INFO {
    ULONG_PTR Offset;
    ULONG_PTR Flags;
  } CFG_CALL_TARGET_INFO, *PCFG_CALL_TARGET_INFO;

#define SECTION_QUERY 0x0001
#define SECTION_MAP_WRITE 0x0002
#define SECTION_MAP_READ 0x0004
#define SECTION_MAP_EXECUTE 0x0008
#define SECTION_EXTEND_SIZE 0x0010
#define SECTION_MAP_EXECUTE_EXPLICIT 0x0020

#define SECTION_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED|SECTION_QUERY| SECTION_MAP_WRITE | SECTION_MAP_READ | SECTION_MAP_EXECUTE | SECTION_EXTEND_SIZE)

#define SESSION_QUERY_ACCESS 0x1
#define SESSION_MODIFY_ACCESS 0x2

#define SESSION_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED | SESSION_QUERY_ACCESS | SESSION_MODIFY_ACCESS)

#define PAGE_NOACCESS 0x01
#define PAGE_READONLY 0x02
#define PAGE_READWRITE 0x04
#define PAGE_WRITECOPY 0x08
#define PAGE_EXECUTE 0x10
#define PAGE_EXECUTE_READ 0x20
#define PAGE_EXECUTE_READWRITE 0x40
#define PAGE_EXECUTE_WRITECOPY 0x80
#define PAGE_GUARD 0x100
#define PAGE_NOCACHE 0x200
#define PAGE_WRITECOMBINE 0x400
#define PAGE_GRAPHICS_NOACCESS 0x0800
#define PAGE_GRAPHICS_READONLY 0x1000
#define PAGE_GRAPHICS_READWRITE 0x2000
#define PAGE_GRAPHICS_EXECUTE 0x4000
#define PAGE_GRAPHICS_EXECUTE_READ 0x8000
#define PAGE_GRAPHICS_EXECUTE_READWRITE 0x10000
#define PAGE_GRAPHICS_COHERENT 0x20000
#define PAGE_ENCLAVE_THREAD_CONTROL 0x80000000
#define PAGE_REVERT_TO_FILE_MAP 0x80000000
#define PAGE_TARGETS_NO_UPDATE 0x40000000
#define PAGE_TARGETS_INVALID 0x40000000
#define PAGE_ENCLAVE_UNVALIDATED 0x20000000
#define PAGE_ENCLAVE_DECOMMIT 0x10000000

#define MEM_COMMIT 0x1000
#define MEM_RESERVE 0x2000
#define MEM_DECOMMIT 0x4000
#define MEM_RELEASE 0x8000
#define MEM_FREE 0x10000
#define MEM_PRIVATE 0x20000
#define MEM_MAPPED 0x40000
#define MEM_RESET 0x80000
#define MEM_TOP_DOWN 0x100000
#define MEM_WRITE_WATCH 0x200000
#define MEM_PHYSICAL 0x400000
#define MEM_ROTATE 0x800000
#define MEM_DIFFERENT_IMAGE_BASE_OK 0x800000
#define MEM_RESET_UNDO 0x1000000
#define MEM_LARGE_PAGES 0x20000000
#define MEM_4MB_PAGES 0x80000000
#define MEM_64K_PAGES (MEM_LARGE_PAGES | MEM_PHYSICAL)

  typedef struct _MEM_ADDRESS_REQUIREMENTS {
    PVOID LowestStartingAddress;
    PVOID HighestEndingAddress;
    SIZE_T Alignment;
  } MEM_ADDRESS_REQUIREMENTS, *PMEM_ADDRESS_REQUIREMENTS;

#define MEM_EXTENDED_PARAMETER_GRAPHICS 0x01
#define MEM_EXTENDED_PARAMETER_NONPAGED 0x02
#define MEM_EXTENDED_PARAMETER_ZERO_PAGES_OPTIONAL 0x04
#define MEM_EXTENDED_PARAMETER_NONPAGED_LARGE 0x08
#define MEM_EXTENDED_PARAMETER_NONPAGED_HUGE 0x10

  typedef enum MEM_EXTENDED_PARAMETER_TYPE {
    MemExtendedParameterInvalidType = 0,
    MemExtendedParameterAddressRequirements,
    MemExtendedParameterNumaNode,
    MemExtendedParameterPartitionHandle,
    MemExtendedParameterUserPhysicalHandle,
    MemExtendedParameterAttributeFlags,
    MemExtendedParameterMax
  } MEM_EXTENDED_PARAMETER_TYPE, *PMEM_EXTENDED_PARAMETER_TYPE;

#define MEM_EXTENDED_PARAMETER_TYPE_BITS 8

  typedef struct DECLSPEC_ALIGN(8) MEM_EXTENDED_PARAMETER {
    __C89_NAMELESS struct {
        DWORD64 Type : MEM_EXTENDED_PARAMETER_TYPE_BITS;
        DWORD64 Reserved : 64 - MEM_EXTENDED_PARAMETER_TYPE_BITS;
    };
    __C89_NAMELESS union {
        DWORD64 ULong64;
        PVOID Pointer;
        SIZE_T Size;
        HANDLE Handle;
        DWORD ULong;
    };
  } MEM_EXTENDED_PARAMETER, *PMEM_EXTENDED_PARAMETER;

#define SEC_PARTITION_OWNER_HANDLE 0x40000
#define SEC_64K_PAGES 0x80000
#define SEC_FILE 0x800000
#define SEC_IMAGE 0x1000000
#define SEC_PROTECTED_IMAGE 0x2000000
#define SEC_RESERVE 0x4000000
#define SEC_COMMIT 0x8000000
#define SEC_NOCACHE 0x10000000
#define SEC_WRITECOMBINE 0x40000000
#define SEC_LARGE_PAGES 0x80000000
#define SEC_IMAGE_NO_EXECUTE (SEC_IMAGE | SEC_NOCACHE)

  typedef enum MEM_SECTION_EXTENDED_PARAMETER_TYPE {
    MemSectionExtendedParameterInvalidType = 0,
    MemSectionExtendedParameterUserPhysicalFlags,
    MemSectionExtendedParameterNumaNode,
    MemSectionExtendedParameterMax
  } MEM_SECTION_EXTENDED_PARAMETER_TYPE, *PMEM_SECTION_EXTENDED_PARAMETER_TYPE;

#define MEM_IMAGE SEC_IMAGE
#define WRITE_WATCH_FLAG_RESET 0x01
#define MEM_UNMAP_WITH_TRANSIENT_BOOST 0x01

#define FILE_READ_DATA (0x0001)
#define FILE_LIST_DIRECTORY (0x0001)

#define FILE_WRITE_DATA (0x0002)
#define FILE_ADD_FILE (0x0002)

#define FILE_APPEND_DATA (0x0004)
#define FILE_ADD_SUBDIRECTORY (0x0004)
#define FILE_CREATE_PIPE_INSTANCE (0x0004)

#define FILE_READ_EA (0x0008)
#define FILE_WRITE_EA (0x0010)
#define FILE_EXECUTE (0x0020)
#define FILE_TRAVERSE (0x0020)
#define FILE_DELETE_CHILD (0x0040)
#define FILE_READ_ATTRIBUTES (0x0080)
#define FILE_WRITE_ATTRIBUTES (0x0100)

#define FILE_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0x1FF)
#define FILE_GENERIC_READ (STANDARD_RIGHTS_READ | FILE_READ_DATA | FILE_READ_ATTRIBUTES | FILE_READ_EA | SYNCHRONIZE)
#define FILE_GENERIC_WRITE (STANDARD_RIGHTS_WRITE | FILE_WRITE_DATA | FILE_WRITE_ATTRIBUTES | FILE_WRITE_EA | FILE_APPEND_DATA | SYNCHRONIZE)
#define FILE_GENERIC_EXECUTE (STANDARD_RIGHTS_EXECUTE | FILE_READ_ATTRIBUTES | FILE_EXECUTE | SYNCHRONIZE)

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

#define FILE_SHARE_READ 0x00000001
#define FILE_SHARE_WRITE 0x00000002
#define FILE_SHARE_DELETE 0x00000004
#define FILE_SHARE_VALID_FLAGS 0x00000007
#define FILE_ATTRIBUTE_READONLY 0x00000001
#define FILE_ATTRIBUTE_HIDDEN 0x00000002
#define FILE_ATTRIBUTE_SYSTEM 0x00000004
#define FILE_ATTRIBUTE_DIRECTORY 0x00000010
#define FILE_ATTRIBUTE_ARCHIVE 0x00000020
#define FILE_ATTRIBUTE_DEVICE 0x00000040
#define FILE_ATTRIBUTE_NORMAL 0x00000080
#define FILE_ATTRIBUTE_TEMPORARY 0x00000100
#define FILE_ATTRIBUTE_SPARSE_FILE 0x00000200
#define FILE_ATTRIBUTE_REPARSE_POINT 0x00000400
#define FILE_ATTRIBUTE_COMPRESSED 0x00000800
#define FILE_ATTRIBUTE_OFFLINE 0x00001000
#define FILE_ATTRIBUTE_NOT_CONTENT_INDEXED 0x00002000
#define FILE_ATTRIBUTE_ENCRYPTED 0x00004000
#define FILE_ATTRIBUTE_VIRTUAL 0x00010000
#define FILE_NOTIFY_CHANGE_FILE_NAME 0x00000001
#define FILE_NOTIFY_CHANGE_DIR_NAME 0x00000002
#define FILE_NOTIFY_CHANGE_ATTRIBUTES 0x00000004
#define FILE_NOTIFY_CHANGE_SIZE 0x00000008
#define FILE_NOTIFY_CHANGE_LAST_WRITE 0x00000010
#define FILE_NOTIFY_CHANGE_LAST_ACCESS 0x00000020
#define FILE_NOTIFY_CHANGE_CREATION 0x00000040
#define FILE_NOTIFY_CHANGE_SECURITY 0x00000100
#define FILE_ACTION_ADDED 0x00000001
#define FILE_ACTION_REMOVED 0x00000002
#define FILE_ACTION_MODIFIED 0x00000003
#define FILE_ACTION_RENAMED_OLD_NAME 0x00000004
#define FILE_ACTION_RENAMED_NEW_NAME 0x00000005
#define MAILSLOT_NO_MESSAGE ((DWORD)-1)
#define MAILSLOT_WAIT_FOREVER ((DWORD)-1)
#define FILE_CASE_SENSITIVE_SEARCH 0x00000001
#define FILE_CASE_PRESERVED_NAMES 0x00000002
#define FILE_UNICODE_ON_DISK 0x00000004
#define FILE_PERSISTENT_ACLS 0x00000008
#define FILE_FILE_COMPRESSION 0x00000010
#define FILE_VOLUME_QUOTAS 0x00000020
#define FILE_SUPPORTS_SPARSE_FILES 0x00000040
#define FILE_SUPPORTS_REPARSE_POINTS 0x00000080
#define FILE_SUPPORTS_REMOTE_STORAGE 0x00000100
#define FILE_VOLUME_IS_COMPRESSED 0x00008000
#define FILE_SUPPORTS_OBJECT_IDS 0x00010000
#define FILE_SUPPORTS_ENCRYPTION 0x00020000
#define FILE_NAMED_STREAMS 0x00040000
#define FILE_READ_ONLY_VOLUME 0x00080000
#define FILE_SEQUENTIAL_WRITE_ONCE 0x00100000
#define FILE_SUPPORTS_TRANSACTIONS 0x00200000
#define FILE_SUPPORTS_HARD_LINKS 0x00400000
#define FILE_SUPPORTS_EXTENDED_ATTRIBUTES 0x00800000
#define FILE_SUPPORTS_OPEN_BY_FILE_ID 0x01000000
#define FILE_SUPPORTS_USN_JOURNAL 0x02000000
#define FILE_SUPPORTS_INTEGRITY_STREAMS 0x04000000

    typedef struct FILE_ID_128 {
      BYTE Identifier[16];
    } FILE_ID_128, *PFILE_ID_128;

    typedef struct _FILE_NOTIFY_INFORMATION {
      DWORD NextEntryOffset;
      DWORD Action;
      DWORD FileNameLength;
      WCHAR FileName[1];
    } FILE_NOTIFY_INFORMATION,*PFILE_NOTIFY_INFORMATION;

    typedef union _FILE_SEGMENT_ELEMENT {
      PVOID64 Buffer;
      ULONGLONG Alignment;
    } FILE_SEGMENT_ELEMENT,*PFILE_SEGMENT_ELEMENT;

    typedef struct _REPARSE_GUID_DATA_BUFFER {
      DWORD ReparseTag;
      WORD ReparseDataLength;
      WORD Reserved;
      GUID ReparseGuid;
      struct {
	BYTE DataBuffer[1];
      } GenericReparseBuffer;
    } REPARSE_GUID_DATA_BUFFER,*PREPARSE_GUID_DATA_BUFFER;

#define REPARSE_GUID_DATA_BUFFER_HEADER_SIZE FIELD_OFFSET(REPARSE_GUID_DATA_BUFFER,GenericReparseBuffer)

#define MAXIMUM_REPARSE_DATA_BUFFER_SIZE (16 *1024)

#define SYMLINK_FLAG_RELATIVE   1

#define IO_REPARSE_TAG_RESERVED_ZERO (0)
#define IO_REPARSE_TAG_RESERVED_ONE (1)

#define IO_REPARSE_TAG_RESERVED_RANGE IO_REPARSE_TAG_RESERVED_ONE

#define IsReparseTagMicrosoft(_tag) (((_tag) & 0x80000000))
#define IsReparseTagNameSurrogate(_tag) (((_tag) & 0x20000000))

#define IO_REPARSE_TAG_MOUNT_POINT (__MSABI_LONG(0xA0000003))
#define IO_REPARSE_TAG_HSM (__MSABI_LONG(0xC0000004))
#define IO_REPARSE_TAG_DRIVE_EXTENDER (__MSABI_LONG(0x80000005))
#define IO_REPARSE_TAG_HSM2 (__MSABI_LONG(0x80000006))
#define IO_REPARSE_TAG_SIS (__MSABI_LONG(0x80000007))
#define IO_REPARSE_TAG_WIM (__MSABI_LONG(0x80000008))
#define IO_REPARSE_TAG_CSV (__MSABI_LONG(0x80000009))
#define IO_REPARSE_TAG_DFS (__MSABI_LONG(0x8000000A))
#define IO_REPARSE_TAG_FILTER_MANAGER (__MSABI_LONG(0x8000000B))
#define IO_REPARSE_TAG_SYMLINK (__MSABI_LONG(0xA000000C))
#define IO_REPARSE_TAG_IIS_CACHE (__MSABI_LONG(0xA0000010))
#define IO_REPARSE_TAG_DFSR (__MSABI_LONG(0x80000012))
#define IO_REPARSE_TAG_DEDUP (__MSABI_LONG(0x80000013))
#define IO_REPARSE_TAG_NFS (__MSABI_LONG(0x80000014))
#define IO_REPARSE_TAG_FILE_PLACEHOLDER (__MSABI_LONG(0x80000015))
#define IO_REPARSE_TAG_WOF (__MSABI_LONG(0x80000017))
#define IO_REPARSE_TAG_WCI (__MSABI_LONG(0x80000018))
#define IO_REPARSE_TAG_WCI_1 (__MSABI_LONG(0x90001018))
#define IO_REPARSE_TAG_GLOBAL_REPARSE (__MSABI_LONG(0xA0000019))
#define IO_REPARSE_TAG_CLOUD (__MSABI_LONG(0x9000001A))
#define IO_REPARSE_TAG_CLOUD_1 (__MSABI_LONG(0x9000101A))
#define IO_REPARSE_TAG_CLOUD_2 (__MSABI_LONG(0x9000201A))
#define IO_REPARSE_TAG_CLOUD_3 (__MSABI_LONG(0x9000301A))
#define IO_REPARSE_TAG_CLOUD_4 (__MSABI_LONG(0x9000401A))
#define IO_REPARSE_TAG_CLOUD_5 (__MSABI_LONG(0x9000501A))
#define IO_REPARSE_TAG_CLOUD_6 (__MSABI_LONG(0x9000601A))
#define IO_REPARSE_TAG_CLOUD_7 (__MSABI_LONG(0x9000701A))
#define IO_REPARSE_TAG_CLOUD_8 (__MSABI_LONG(0x9000801A))
#define IO_REPARSE_TAG_CLOUD_9 (__MSABI_LONG(0x9000901A))
#define IO_REPARSE_TAG_CLOUD_A (__MSABI_LONG(0x9000A01A))
#define IO_REPARSE_TAG_CLOUD_B (__MSABI_LONG(0x9000B01A))
#define IO_REPARSE_TAG_CLOUD_C (__MSABI_LONG(0x9000C01A))
#define IO_REPARSE_TAG_CLOUD_D (__MSABI_LONG(0x9000D01A))
#define IO_REPARSE_TAG_CLOUD_E (__MSABI_LONG(0x9000E01A))
#define IO_REPARSE_TAG_CLOUD_F (__MSABI_LONG(0x9000F01A))
#define IO_REPARSE_TAG_CLOUD_MASK (__MSABI_LONG(0x0000F000))
#define IO_REPARSE_TAG_APPEXECLINK (__MSABI_LONG(0x8000001B))
#define IO_REPARSE_TAG_PROJFS (__MSABI_LONG(0x9000001C))
#define IO_REPARSE_TAG_STORAGE_SYNC (__MSABI_LONG(0x8000001E))
#define IO_REPARSE_TAG_WCI_TOMBSTONE (__MSABI_LONG(0xA000001F))
#define IO_REPARSE_TAG_UNHANDLED (__MSABI_LONG(0x80000020))
#define IO_REPARSE_TAG_ONEDRIVE (__MSABI_LONG(0x80000021))
#define IO_REPARSE_TAG_PROJFS_TOMBSTONE (__MSABI_LONG(0xA0000022))
#define IO_REPARSE_TAG_AF_UNIX (__MSABI_LONG(0x80000023))

#if _WIN32_WINNT >= 0x0602
#define SCRUB_DATA_INPUT_FLAG_RESUME 0x00000001
#define SCRUB_DATA_INPUT_FLAG_SKIP_IN_SYNC 0x00000002
#define SCRUB_DATA_INPUT_FLAG_SKIP_NON_INTEGRITY_DATA 0x00000004

#define SCRUB_DATA_OUTPUT_FLAG_INCOMPLETE 0x00000001
#define SCRUB_DATA_OUTPUT_FLAG_NON_USER_DATA_RANGE 0x00010000

    typedef struct _SCRUB_DATA_INPUT {
      DWORD Size;
      DWORD Flags;
      DWORD MaximumIos;
      DWORD Reserved[17];
      BYTE ResumeContext[816];
    } SCRUB_DATA_INPUT,*PSCRUB_DATA_INPUT;

    typedef struct _SCRUB_DATA_OUTPUT {
      DWORD Size;
      DWORD Flags;
      DWORD Status;
      ULONGLONG ErrorFileOffset;
      ULONGLONG ErrorLength;
      ULONGLONG NumberOfBytesRepaired;
      ULONGLONG NumberOfBytesFailed;
      ULONGLONG InternalFileReference;
      DWORD Reserved[6];
      BYTE ResumeContext[816];
    } SCRUB_DATA_OUTPUT,*PSCRUB_DATA_OUTPUT;
#endif

#define IO_COMPLETION_MODIFY_STATE 0x0002
#define IO_COMPLETION_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED|SYNCHRONIZE|0x3)
#define DUPLICATE_CLOSE_SOURCE 0x00000001
#define DUPLICATE_SAME_ACCESS 0x00000002

#define POWERBUTTON_ACTION_INDEX_NOTHING 0
#define POWERBUTTON_ACTION_INDEX_SLEEP 1
#define POWERBUTTON_ACTION_INDEX_HIBERNATE 2
#define POWERBUTTON_ACTION_INDEX_SHUTDOWN 3

#define POWERBUTTON_ACTION_VALUE_NOTHING 0
#define POWERBUTTON_ACTION_VALUE_SLEEP 2
#define POWERBUTTON_ACTION_VALUE_HIBERNATE 3
#define POWERBUTTON_ACTION_VALUE_SHUTDOWN 6

#define PERFSTATE_POLICY_CHANGE_IDEAL 0
#define PERFSTATE_POLICY_CHANGE_SINGLE 1
#define PERFSTATE_POLICY_CHANGE_ROCKET 2
#define PERFSTATE_POLICY_CHANGE_MAX PERFSTATE_POLICY_CHANGE_ROCKET

#define PROCESSOR_PERF_BOOST_POLICY_DISABLED 0
#define PROCESSOR_PERF_BOOST_POLICY_MAX 100

#define PROCESSOR_PERF_BOOST_MODE_DISABLED 0
#define PROCESSOR_PERF_BOOST_MODE_ENABLED 1
#define PROCESSOR_PERF_BOOST_MODE_AGGRESSIVE 2
#define PROCESSOR_PERF_BOOST_MODE_EFFICIENT_ENABLED 3
#define PROCESSOR_PERF_BOOST_MODE_EFFICIENT_AGGRESSIVE 4
#define PROCESSOR_PERF_BOOST_MODE_MAX PROCESSOR_PERF_BOOST_MODE_EFFICIENT_AGGRESSIVE

#define CORE_PARKING_POLICY_CHANGE_IDEAL 0
#define CORE_PARKING_POLICY_CHANGE_SINGLE 1
#define CORE_PARKING_POLICY_CHANGE_ROCKET 2
#define CORE_PARKING_POLICY_CHANGE_MULTISTEP 3
#define CORE_PARKING_POLICY_CHANGE_MAX CORE_PARKING_POLICY_CHANGE_MULTISTEP

#define POWER_DEVICE_IDLE_POLICY_PERFORMANCE 0
#define POWER_DEVICE_IDLE_POLICY_CONSERVATIVE 1

    DEFINE_GUID (GUID_MAX_POWER_SAVINGS, 0xa1841308, 0x3541, 0x4fab, 0xbc, 0x81, 0xf7, 0x15, 0x56, 0xf2, 0x0b, 0x4a);
    DEFINE_GUID (GUID_MIN_POWER_SAVINGS, 0x8c5e7fda, 0xe8bf, 0x4a96, 0x9a, 0x85, 0xa6, 0xe2, 0x3a, 0x8c, 0x63, 0x5c);
    DEFINE_GUID (GUID_TYPICAL_POWER_SAVINGS, 0x381b4222, 0xf694, 0x41f0, 0x96, 0x85, 0xff, 0x5b, 0xb2, 0x60, 0xdf, 0x2e);
    DEFINE_GUID (NO_SUBGROUP_GUID, 0xfea3413e, 0x7e05, 0x4911, 0x9a, 0x71, 0x70, 0x03, 0x31, 0xf1, 0xc2, 0x94);
    DEFINE_GUID (ALL_POWERSCHEMES_GUID, 0x68a1e95e, 0x13ea, 0x41e1, 0x80, 0x11, 0x0c, 0x49, 0x6c, 0xa4, 0x90, 0xb0);
    DEFINE_GUID (GUID_POWERSCHEME_PERSONALITY, 0x245d8541, 0x3943, 0x4422, 0xb0, 0x25, 0x13, 0xa7, 0x84, 0xf6, 0x79, 0xb7);
    DEFINE_GUID (GUID_ACTIVE_POWERSCHEME, 0x31f9f286, 0x5084, 0x42fe, 0xb7, 0x20, 0x2b, 0x02, 0x64, 0x99, 0x37, 0x63);
    DEFINE_GUID (GUID_IDLE_RESILIENCY_SUBGROUP, 0x2e601130, 0x5351, 0x4d9d, 0x8e, 0x4, 0x25, 0x29, 0x66, 0xba, 0xd0, 0x54);
    DEFINE_GUID (GUID_IDLE_RESILIENCY_PERIOD, 0xc42b79aa, 0xaa3a, 0x484b, 0xa9, 0x8f, 0x2c, 0xf3, 0x2a, 0xa9, 0xa, 0x28);
    DEFINE_GUID (GUID_DISK_COALESCING_POWERDOWN_TIMEOUT, 0xc36f0eb4, 0x2988, 0x4a70, 0x8e, 0xee, 0x8, 0x84, 0xfc, 0x2c, 0x24, 0x33);
    DEFINE_GUID (GUID_EXECUTION_REQUIRED_REQUEST_TIMEOUT, 0x3166bc41, 0x7e98, 0x4e03, 0xb3, 0x4e, 0xec, 0xf, 0x5f, 0x2b, 0x21, 0x8e);
    DEFINE_GUID (GUID_VIDEO_SUBGROUP, 0x7516b95f, 0xf776, 0x4464, 0x8c, 0x53, 0x06, 0x16, 0x7f, 0x40, 0xcc, 0x99);
    DEFINE_GUID (GUID_VIDEO_POWERDOWN_TIMEOUT, 0x3c0bc021, 0xc8a8, 0x4e07, 0xa9, 0x73, 0x6b, 0x14, 0xcb, 0xcb, 0x2b, 0x7e);
    DEFINE_GUID (GUID_VIDEO_ANNOYANCE_TIMEOUT, 0x82dbcf2d, 0xcd67, 0x40c5, 0xbf, 0xdc, 0x9f, 0x1a, 0x5c, 0xcd, 0x46, 0x63);
    DEFINE_GUID (GUID_VIDEO_ADAPTIVE_PERCENT_INCREASE, 0xeed904df, 0xb142, 0x4183, 0xb1, 0x0b, 0x5a, 0x11, 0x97, 0xa3, 0x78, 0x64);
    DEFINE_GUID (GUID_VIDEO_DIM_TIMEOUT, 0x17aaa29b, 0x8b43, 0x4b94, 0xaa, 0xfe, 0x35, 0xf6, 0x4d, 0xaa, 0xf1, 0xee);
    DEFINE_GUID (GUID_VIDEO_ADAPTIVE_POWERDOWN, 0x90959d22, 0xd6a1, 0x49b9, 0xaf, 0x93, 0xbc, 0xe8, 0x85, 0xad, 0x33, 0x5b);
    DEFINE_GUID (GUID_MONITOR_POWER_ON, 0x02731015, 0x4510, 0x4526, 0x99, 0xe6, 0xe5, 0xa1, 0x7e, 0xbd, 0x1a, 0xea);
    DEFINE_GUID (GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS, __MSABI_LONG(0xaded5e82), 0xb909, 0x4619, 0x99, 0x49, 0xf5, 0xd7, 0x1d, 0xac, 0x0b, 0xcb);
    DEFINE_GUID (GUID_DEVICE_POWER_POLICY_VIDEO_DIM_BRIGHTNESS, 0xf1fbfde2, 0xa960, 0x4165, 0x9f, 0x88, 0x50, 0x66, 0x79, 0x11, 0xce, 0x96);
    DEFINE_GUID (GUID_VIDEO_CURRENT_MONITOR_BRIGHTNESS, 0x8ffee2c6, 0x2d01, 0x46be, 0xad, 0xb9, 0x39, 0x8a, 0xdd, 0xc5, 0xb4, 0xff);
    DEFINE_GUID (GUID_VIDEO_ADAPTIVE_DISPLAY_BRIGHTNESS, 0xfbd9aa66, 0x9553, 0x4097, 0xba, 0x44, 0xed, 0x6e, 0x9d, 0x65, 0xea, 0xb8);
    DEFINE_GUID (GUID_CONSOLE_DISPLAY_STATE, 0x6fe69556, 0x704a, 0x47a0, 0x8f, 0x24, 0xc2, 0x8d, 0x93, 0x6f, 0xda, 0x47);
    DEFINE_GUID (GUID_ALLOW_DISPLAY_REQUIRED, 0xa9ceb8da, 0xcd46, 0x44fb, 0xa9, 0x8b, 0x02, 0xaf, 0x69, 0xde, 0x46, 0x23);
    DEFINE_GUID (GUID_VIDEO_CONSOLE_LOCK_TIMEOUT, 0x8ec4b3a5, 0x6868, 0x48c2, 0xbe, 0x75, 0x4f, 0x30, 0x44, 0xbe, 0x88, 0xa7);
    DEFINE_GUID (GUID_ADAPTIVE_POWER_BEHAVIOR_SUBGROUP, 0x8619b916, 0xe004, 0x4dd8, 0x9b, 0x66, 0xda, 0xe8, 0x6f, 0x80, 0x66, 0x98);
    DEFINE_GUID (GUID_NON_ADAPTIVE_INPUT_TIMEOUT, 0x5adbbfbc, 0x74e, 0x4da1, 0xba, 0x38, 0xdb, 0x8b, 0x36, 0xb2, 0xc8, 0xf3);
    DEFINE_GUID (GUID_DISK_SUBGROUP, 0x0012ee47, 0x9041, 0x4b5d, 0x9b, 0x77, 0x53, 0x5f, 0xba, 0x8b, 0x14, 0x42);
    DEFINE_GUID (GUID_DISK_POWERDOWN_TIMEOUT, 0x6738e2c4, 0xe8a5, 0x4a42, 0xb1, 0x6a, 0xe0, 0x40, 0xe7, 0x69, 0x75, 0x6e);
    DEFINE_GUID (GUID_DISK_IDLE_TIMEOUT, 0x58e39ba8, 0xb8e6, 0x4ef6, 0x90, 0xd0, 0x89, 0xae, 0x32, 0xb2, 0x58, 0xd6);
    DEFINE_GUID (GUID_DISK_BURST_IGNORE_THRESHOLD, 0x80e3c60e, 0xbb94, 0x4ad8, 0xbb, 0xe0, 0x0d, 0x31, 0x95, 0xef, 0xc6, 0x63);
    DEFINE_GUID (GUID_DISK_ADAPTIVE_POWERDOWN, 0x396a32e1, 0x499a, 0x40b2, 0x91, 0x24, 0xa9, 0x6a, 0xfe, 0x70, 0x76, 0x67);
    DEFINE_GUID (GUID_SLEEP_SUBGROUP, 0x238c9fa8, 0x0aad, 0x41ed, 0x83, 0xf4, 0x97, 0xbe, 0x24, 0x2c, 0x8f, 0x20);
    DEFINE_GUID (GUID_SLEEP_IDLE_THRESHOLD, 0x81cd32e0, 0x7833, 0x44f3, 0x87, 0x37, 0x70, 0x81, 0xf3, 0x8d, 0x1f, 0x70);
    DEFINE_GUID (GUID_STANDBY_TIMEOUT, 0x29f6c1db, 0x86da, 0x48c5, 0x9f, 0xdb, 0xf2, 0xb6, 0x7b, 0x1f, 0x44, 0xda);
    DEFINE_GUID (GUID_UNATTEND_SLEEP_TIMEOUT, 0x7bc4a2f9, 0xd8fc, 0x4469, 0xb0, 0x7b, 0x33, 0xeb, 0x78, 0x5a, 0xac, 0xa0);
    DEFINE_GUID (GUID_HIBERNATE_TIMEOUT, 0x9d7815a6, 0x7ee4, 0x497e, 0x88, 0x88, 0x51, 0x5a, 0x05, 0xf0, 0x23, 0x64);
    DEFINE_GUID (GUID_HIBERNATE_FASTS4_POLICY, 0x94ac6d29, 0x73ce, 0x41a6, 0x80, 0x9f, 0x63, 0x63, 0xba, 0x21, 0xb4, 0x7e);
    DEFINE_GUID (GUID_CRITICAL_POWER_TRANSITION, 0xb7a27025, 0xe569, 0x46c2, 0xa5, 0x04, 0x2b, 0x96, 0xca, 0xd2, 0x25, 0xa1);
    DEFINE_GUID (GUID_SYSTEM_AWAYMODE, 0x98a7f580, 0x01f7, 0x48aa, 0x9c, 0x0f, 0x44, 0x35, 0x2c, 0x29, 0xe5, 0xc0);
    DEFINE_GUID (GUID_ALLOW_AWAYMODE, 0x25dfa149, 0x5dd1, 0x4736, 0xb5, 0xab, 0xe8, 0xa3, 0x7b, 0x5b, 0x81, 0x87);
    DEFINE_GUID (GUID_ALLOW_STANDBY_STATES, 0xabfc2519, 0x3608, 0x4c2a, 0x94, 0xea, 0x17, 0x1b, 0x0e, 0xd5, 0x46, 0xab);
    DEFINE_GUID (GUID_ALLOW_RTC_WAKE, 0xbd3b718a, 0x0680, 0x4d9d, 0x8a, 0xb2, 0xe1, 0xd2, 0xb4, 0xac, 0x80, 0x6d);
    DEFINE_GUID (GUID_ALLOW_SYSTEM_REQUIRED, 0xa4b195f5, 0x8225, 0x47d8, 0x80, 0x12, 0x9d, 0x41, 0x36, 0x97, 0x86, 0xe2);
    DEFINE_GUID (GUID_SYSTEM_BUTTON_SUBGROUP, 0x4f971e89, 0xeebd, 0x4455, 0xa8, 0xde, 0x9e, 0x59, 0x04, 0x0e, 0x73, 0x47);
    DEFINE_GUID (GUID_POWERBUTTON_ACTION, 0x7648efa3, 0xdd9c, 0x4e3e, 0xb5, 0x66, 0x50, 0xf9, 0x29, 0x38, 0x62, 0x80);
    DEFINE_GUID (GUID_SLEEPBUTTON_ACTION, 0x96996bc0, 0xad50, 0x47ec, 0x92, 0x3b, 0x6f, 0x41, 0x87, 0x4d, 0xd9, 0xeb);
    DEFINE_GUID (GUID_USERINTERFACEBUTTON_ACTION, 0xa7066653, 0x8d6c, 0x40a8, 0x91, 0x0e, 0xa1, 0xf5, 0x4b, 0x84, 0xc7, 0xe5);
    DEFINE_GUID (GUID_LIDCLOSE_ACTION, 0x5ca83367, 0x6e45, 0x459f, 0xa2, 0x7b, 0x47, 0x6b, 0x1d, 0x01, 0xc9, 0x36);
    DEFINE_GUID (GUID_LIDOPEN_POWERSTATE, 0x99ff10e7, 0x23b1, 0x4c07, 0xa9, 0xd1, 0x5c, 0x32, 0x06, 0xd7, 0x41, 0xb4);
    DEFINE_GUID (GUID_BATTERY_SUBGROUP, 0xe73a048d, 0xbf27, 0x4f12, 0x97, 0x31, 0x8b, 0x20, 0x76, 0xe8, 0x89, 0x1f);
    DEFINE_GUID (GUID_BATTERY_DISCHARGE_ACTION_0, 0x637ea02f, 0xbbcb, 0x4015, 0x8e, 0x2c, 0xa1, 0xc7, 0xb9, 0xc0, 0xb5, 0x46);
    DEFINE_GUID (GUID_BATTERY_DISCHARGE_LEVEL_0, 0x9a66d8d7, 0x4ff7, 0x4ef9, 0xb5, 0xa2, 0x5a, 0x32, 0x6c, 0xa2, 0xa4, 0x69);
    DEFINE_GUID (GUID_BATTERY_DISCHARGE_FLAGS_0, 0x5dbb7c9f, 0x38e9, 0x40d2, 0x97, 0x49, 0x4f, 0x8a, 0x0e, 0x9f, 0x64, 0x0f);
    DEFINE_GUID (GUID_BATTERY_DISCHARGE_ACTION_1, 0xd8742dcb, 0x3e6a, 0x4b3c, 0xb3, 0xfe, 0x37, 0x46, 0x23, 0xcd, 0xcf, 0x06);
    DEFINE_GUID (GUID_BATTERY_DISCHARGE_LEVEL_1, 0x8183ba9a, 0xe910, 0x48da, 0x87, 0x69, 0x14, 0xae, 0x6d, 0xc1, 0x17, 0x0a);
    DEFINE_GUID (GUID_BATTERY_DISCHARGE_FLAGS_1, 0xbcded951, 0x187b, 0x4d05, 0xbc, 0xcc, 0xf7, 0xe5, 0x19, 0x60, 0xc2, 0x58);
    DEFINE_GUID (GUID_BATTERY_DISCHARGE_ACTION_2, 0x421cba38, 0x1a8e, 0x4881, 0xac, 0x89, 0xe3, 0x3a, 0x8b, 0x04, 0xec, 0xe4);
    DEFINE_GUID (GUID_BATTERY_DISCHARGE_LEVEL_2, 0x07a07ca2, 0xadaf, 0x40d7, 0xb0, 0x77, 0x53, 0x3a, 0xad, 0xed, 0x1b, 0xfa);
    DEFINE_GUID (GUID_BATTERY_DISCHARGE_FLAGS_2, 0x7fd2f0c4, 0xfeb7, 0x4da3, 0x81, 0x17, 0xe3, 0xfb, 0xed, 0xc4, 0x65, 0x82);
    DEFINE_GUID (GUID_BATTERY_DISCHARGE_ACTION_3, 0x80472613, 0x9780, 0x455e, 0xb3, 0x08, 0x72, 0xd3, 0x00, 0x3c, 0xf2, 0xf8);
    DEFINE_GUID (GUID_BATTERY_DISCHARGE_LEVEL_3, 0x58afd5a6, 0xc2dd, 0x47d2, 0x9f, 0xbf, 0xef, 0x70, 0xcc, 0x5c, 0x59, 0x65);
    DEFINE_GUID (GUID_BATTERY_DISCHARGE_FLAGS_3, 0x73613ccf, 0xdbfa, 0x4279, 0x83, 0x56, 0x49, 0x35, 0xf6, 0xbf, 0x62, 0xf3);
    DEFINE_GUID (GUID_PROCESSOR_SETTINGS_SUBGROUP, 0x54533251, 0x82be, 0x4824, 0x96, 0xc1, 0x47, 0xb6, 0x0b, 0x74, 0x0d, 0x00);
    DEFINE_GUID (GUID_PROCESSOR_THROTTLE_POLICY, 0x57027304, 0x4af6, 0x4104, 0x92, 0x60, 0xe3, 0xd9, 0x52, 0x48, 0xfc, 0x36);
    DEFINE_GUID (GUID_PROCESSOR_THROTTLE_MAXIMUM, 0xbc5038f7, 0x23e0, 0x4960, 0x96, 0xda, 0x33, 0xab, 0xaf, 0x59, 0x35, 0xec);
    DEFINE_GUID (GUID_PROCESSOR_THROTTLE_MINIMUM, 0x893dee8e, 0x2bef, 0x41e0, 0x89, 0xc6, 0xb5, 0x5d, 0x09, 0x29, 0x96, 0x4c);
    DEFINE_GUID (GUID_PROCESSOR_ALLOW_THROTTLING, 0x3b04d4fd, 0x1cc7, 0x4f23, 0xab, 0x1c, 0xd1, 0x33, 0x78, 0x19, 0xc4, 0xbb);
    DEFINE_GUID (GUID_PROCESSOR_IDLESTATE_POLICY, 0x68f262a7, 0xf621, 0x4069, 0xb9, 0xa5, 0x48, 0x74, 0x16, 0x9b, 0xe2, 0x3c);
    DEFINE_GUID (GUID_PROCESSOR_PERFSTATE_POLICY, 0xbbdc3814, 0x18e9, 0x4463, 0x8a, 0x55, 0xd1, 0x97, 0x32, 0x7c, 0x45, 0xc0);
    DEFINE_GUID (GUID_PROCESSOR_PERF_INCREASE_THRESHOLD, 0x06cadf0e, 0x64ed, 0x448a, 0x89, 0x27, 0xce, 0x7b, 0xf9, 0x0e, 0xb3, 0x5d);
    DEFINE_GUID (GUID_PROCESSOR_PERF_DECREASE_THRESHOLD, 0x12a0ab44, 0xfe28, 0x4fa9, 0xb3, 0xbd, 0x4b, 0x64, 0xf4, 0x49, 0x60, 0xa6);
    DEFINE_GUID (GUID_PROCESSOR_PERF_INCREASE_POLICY, 0x465e1f50, 0xb610, 0x473a, 0xab, 0x58, 0x0, 0xd1, 0x7, 0x7d, 0xc4, 0x18);
    DEFINE_GUID (GUID_PROCESSOR_PERF_DECREASE_POLICY, 0x40fbefc7, 0x2e9d, 0x4d25, 0xa1, 0x85, 0xc, 0xfd, 0x85, 0x74, 0xba, 0xc6);
    DEFINE_GUID (GUID_PROCESSOR_PERF_INCREASE_TIME, 0x984cf492, 0x3bed, 0x4488, 0xa8, 0xf9, 0x42, 0x86, 0xc9, 0x7b, 0xf5, 0xaa);
    DEFINE_GUID (GUID_PROCESSOR_PERF_DECREASE_TIME, 0xd8edeb9b, 0x95cf, 0x4f95, 0xa7, 0x3c, 0xb0, 0x61, 0x97, 0x36, 0x93, 0xc8);
    DEFINE_GUID (GUID_PROCESSOR_PERF_TIME_CHECK, 0x4d2b0152, 0x7d5c, 0x498b, 0x88, 0xe2, 0x34, 0x34, 0x53, 0x92, 0xa2, 0xc5);
    DEFINE_GUID (GUID_PROCESSOR_PERF_BOOST_POLICY, 0x45bcc044, 0xd885, 0x43e2, 0x86, 0x5, 0xee, 0xe, 0xc6, 0xe9, 0x6b, 0x59);
    DEFINE_GUID (GUID_PROCESSOR_PERF_BOOST_MODE, 0xbe337238, 0xd82, 0x4146, 0xa9, 0x60, 0x4f, 0x37, 0x49, 0xd4, 0x70, 0xc7);
    DEFINE_GUID (GUID_PROCESSOR_IDLE_ALLOW_SCALING, 0x6c2993b0, 0x8f48, 0x481f, 0xbc, 0xc6, 0x0, 0xdd, 0x27, 0x42, 0xaa, 0x6);
    DEFINE_GUID (GUID_PROCESSOR_IDLE_DISABLE, 0x5d76a2ca, 0xe8c0, 0x402f, 0xa1, 0x33, 0x21, 0x58, 0x49, 0x2d, 0x58, 0xad);
    DEFINE_GUID (GUID_PROCESSOR_IDLE_STATE_MAXIMUM, 0x9943e905, 0x9a30, 0x4ec1, 0x9b, 0x99, 0x44, 0xdd, 0x3b, 0x76, 0xf7, 0xa2);
    DEFINE_GUID (GUID_PROCESSOR_IDLE_TIME_CHECK, 0xc4581c31, 0x89ab, 0x4597, 0x8e, 0x2b, 0x9c, 0x9c, 0xab, 0x44, 0xe, 0x6b);
    DEFINE_GUID (GUID_PROCESSOR_IDLE_DEMOTE_THRESHOLD, 0x4b92d758, 0x5a24, 0x4851, 0xa4, 0x70, 0x81, 0x5d, 0x78, 0xae, 0xe1, 0x19);
    DEFINE_GUID (GUID_PROCESSOR_IDLE_PROMOTE_THRESHOLD, 0x7b224883, 0xb3cc, 0x4d79, 0x81, 0x9f, 0x83, 0x74, 0x15, 0x2c, 0xbe, 0x7c);
    DEFINE_GUID (GUID_PROCESSOR_CORE_PARKING_INCREASE_THRESHOLD, 0xdf142941, 0x20f3, 0x4edf, 0x9a, 0x4a, 0x9c, 0x83, 0xd3, 0xd7, 0x17, 0xd1);
    DEFINE_GUID (GUID_PROCESSOR_CORE_PARKING_DECREASE_THRESHOLD, 0x68dd2f27, 0xa4ce, 0x4e11, 0x84, 0x87, 0x37, 0x94, 0xe4, 0x13, 0x5d, 0xfa);
    DEFINE_GUID (GUID_PROCESSOR_CORE_PARKING_INCREASE_POLICY, 0xc7be0679, 0x2817, 0x4d69, 0x9d, 0x02, 0x51, 0x9a, 0x53, 0x7e, 0xd0, 0xc6);
    DEFINE_GUID (GUID_PROCESSOR_CORE_PARKING_DECREASE_POLICY, 0x71021b41, 0xc749, 0x4d21, 0xbe, 0x74, 0xa0, 0x0f, 0x33, 0x5d, 0x58, 0x2b);
    DEFINE_GUID (GUID_PROCESSOR_CORE_PARKING_MAX_CORES, 0xea062031, 0x0e34, 0x4ff1, 0x9b, 0x6d, 0xeb, 0x10, 0x59, 0x33, 0x40, 0x28);
    DEFINE_GUID (GUID_PROCESSOR_CORE_PARKING_MIN_CORES, 0x0cc5b647, 0xc1df, 0x4637, 0x89, 0x1a, 0xde, 0xc3, 0x5c, 0x31, 0x85, 0x83);
    DEFINE_GUID (GUID_PROCESSOR_CORE_PARKING_INCREASE_TIME, 0x2ddd5a84, 0x5a71, 0x437e, 0x91, 0x2a, 0xdb, 0x0b, 0x8c, 0x78, 0x87, 0x32);
    DEFINE_GUID (GUID_PROCESSOR_CORE_PARKING_DECREASE_TIME, 0xdfd10d17, 0xd5eb, 0x45dd, 0x87, 0x7a, 0x9a, 0x34, 0xdd, 0xd1, 0x5c, 0x82);
    DEFINE_GUID (GUID_PROCESSOR_CORE_PARKING_AFFINITY_HISTORY_DECREASE_FACTOR, 0x8f7b45e3, 0xc393, 0x480a, 0x87, 0x8c, 0xf6, 0x7a, 0xc3, 0xd0, 0x70, 0x82);
    DEFINE_GUID (GUID_PROCESSOR_CORE_PARKING_AFFINITY_HISTORY_THRESHOLD, 0x5b33697b, 0xe89d, 0x4d38, 0xaa, 0x46, 0x9e, 0x7d, 0xfb, 0x7c, 0xd2, 0xf9);
    DEFINE_GUID (GUID_PROCESSOR_CORE_PARKING_AFFINITY_WEIGHTING, 0xe70867f1, 0xfa2f, 0x4f4e, 0xae, 0xa1, 0x4d, 0x8a, 0x0b, 0xa2, 0x3b, 0x20);
    DEFINE_GUID (GUID_PROCESSOR_CORE_PARKING_OVER_UTILIZATION_HISTORY_DECREASE_FACTOR, 0x1299023c, 0xbc28, 0x4f0a, 0x81, 0xec, 0xd3, 0x29, 0x5a, 0x8d, 0x81, 0x5d);
    DEFINE_GUID (GUID_PROCESSOR_CORE_PARKING_OVER_UTILIZATION_HISTORY_THRESHOLD, 0x9ac18e92, 0xaa3c, 0x4e27, 0xb3, 0x07, 0x01, 0xae, 0x37, 0x30, 0x71, 0x29);
    DEFINE_GUID (GUID_PROCESSOR_CORE_PARKING_OVER_UTILIZATION_WEIGHTING, 0x8809c2d8, 0xb155, 0x42d4, 0xbc, 0xda, 0x0d, 0x34, 0x56, 0x51, 0xb1, 0xdb);
    DEFINE_GUID (GUID_PROCESSOR_CORE_PARKING_OVER_UTILIZATION_THRESHOLD, 0x943c8cb6, 0x6f93, 0x4227, 0xad, 0x87, 0xe9, 0xa3, 0xfe, 0xec, 0x08, 0xd1);
    DEFINE_GUID (GUID_PROCESSOR_PARKING_CORE_OVERRIDE, 0xa55612aa, 0xf624, 0x42c6, 0xa4, 0x43, 0x73, 0x97, 0xd0, 0x64, 0xc0, 0x4f);
    DEFINE_GUID (GUID_PROCESSOR_PARKING_PERF_STATE, 0x447235c7, 0x6a8d, 0x4cc0, 0x8e, 0x24, 0x9e, 0xaf, 0x70, 0xb9, 0x6e, 0x2b);
    DEFINE_GUID (GUID_PROCESSOR_PARKING_CONCURRENCY_THRESHOLD, 0x2430ab6f, 0xa520, 0x44a2, 0x96, 0x01, 0xf7, 0xf2, 0x3b, 0x51, 0x34, 0xb1);
    DEFINE_GUID (GUID_PROCESSOR_PARKING_HEADROOM_THRESHOLD, 0xf735a673, 0x2066, 0x4f80, 0xa0, 0xc5, 0xdd, 0xee, 0x0c, 0xf1, 0xbf, 0x5d);
    DEFINE_GUID (GUID_PROCESSOR_PERF_HISTORY, 0x7d24baa7, 0x0b84, 0x480f, 0x84, 0x0c, 0x1b, 0x07, 0x43, 0xc0, 0x0f, 0x5f);
    DEFINE_GUID (GUID_PROCESSOR_PERF_LATENCY_HINT, 0x0822df31, 0x9c83, 0x441c, 0xa0, 0x79, 0x0d, 0xe4, 0xcf, 0x00, 0x9c, 0x7b);
    DEFINE_GUID (GUID_PROCESSOR_DISTRIBUTE_UTILITY, 0xe0007330, 0xf589, 0x42ed, 0xa4, 0x01, 0x5d, 0xdb, 0x10, 0xe7, 0x85, 0xd3);
    DEFINE_GUID (GUID_SYSTEM_COOLING_POLICY, 0x94d3a615, 0xa899, 0x4ac5, 0xae, 0x2b, 0xe4, 0xd8, 0xf6, 0x34, 0x36, 0x7f);
    DEFINE_GUID (GUID_LOCK_CONSOLE_ON_WAKE, 0x0e796bdb, 0x100d, 0x47d6, 0xa2, 0xd5, 0xf7, 0xd2, 0xda, 0xa5, 0x1f, 0x51);
    DEFINE_GUID (GUID_DEVICE_IDLE_POLICY, 0x4faab71a, 0x92e5, 0x4726, 0xb5, 0x31, 0x22, 0x45, 0x59, 0x67, 0x2d, 0x19);
    DEFINE_GUID (GUID_ACDC_POWER_SOURCE, 0x5d3e9a59, 0xe9d5, 0x4b00, 0xa6, 0xbd, 0xff, 0x34, 0xff, 0x51, 0x65, 0x48);
    DEFINE_GUID (GUID_LIDSWITCH_STATE_CHANGE, 0xba3e0f4d, 0xb817, 0x4094, 0xa2, 0xd1, 0xd5, 0x63, 0x79, 0xe6, 0xa0, 0xf3);
    DEFINE_GUID (GUID_BATTERY_PERCENTAGE_REMAINING, 0xa7ad8041, 0xb45a, 0x4cae, 0x87, 0xa3, 0xee, 0xcb, 0xb4, 0x68, 0xa9, 0xe1);
    DEFINE_GUID (GUID_GLOBAL_USER_PRESENCE, 0x786e8a1d, 0xb427, 0x4344, 0x92, 0x7, 0x9, 0xe7, 0xb, 0xdc, 0xbe, 0xa9);
    DEFINE_GUID (GUID_SESSION_DISPLAY_STATUS, 0x2b84c20e, 0xad23, 0x4ddf, 0x93, 0xdb, 0x5, 0xff, 0xbd, 0x7e, 0xfc, 0xa5);
    DEFINE_GUID (GUID_SESSION_USER_PRESENCE, 0x3c0f4548, 0xc03f, 0x4c4d, 0xb9, 0xf2, 0x23, 0x7e, 0xde, 0x68, 0x63, 0x76);
    DEFINE_GUID (GUID_IDLE_BACKGROUND_TASK, 0x515c31d8, 0xf734, 0x163d, 0xa0, 0xfd, 0x11, 0xa0, 0x8c, 0x91, 0xe8, 0xf1);
    DEFINE_GUID (GUID_BACKGROUND_TASK_NOTIFICATION, 0xcf23f240, 0x2a54, 0x48d8, 0xb1, 0x14, 0xde, 0x15, 0x18, 0xff, 0x05, 0x2e);
    DEFINE_GUID (GUID_APPLAUNCH_BUTTON, 0x1a689231, 0x7399, 0x4e9a, 0x8f, 0x99, 0xb7, 0x1f, 0x99, 0x9d, 0xb3, 0xfa);
    DEFINE_GUID (GUID_PCIEXPRESS_SETTINGS_SUBGROUP, 0x501a4d13, 0x42af, 0x4429, 0x9f, 0xd1, 0xa8, 0x21, 0x8c, 0x26, 0x8e, 0x20);
    DEFINE_GUID (GUID_PCIEXPRESS_ASPM_POLICY, 0xee12f906, 0xd277, 0x404b, 0xb6, 0xda, 0xe5, 0xfa, 0x1a, 0x57, 0x6d, 0xf5);
    DEFINE_GUID (GUID_ENABLE_SWITCH_FORCED_SHUTDOWN, 0x833a6b62, 0xdfa4, 0x46d1, 0x82, 0xf8, 0xe0, 0x9e, 0x34, 0xd0, 0x29, 0xd6);

  typedef enum _SYSTEM_POWER_STATE {
    PowerSystemUnspecified = 0,PowerSystemWorking = 1,PowerSystemSleeping1 = 2,PowerSystemSleeping2 = 3,PowerSystemSleeping3 = 4,PowerSystemHibernate = 5,PowerSystemShutdown = 6,PowerSystemMaximum = 7
  } SYSTEM_POWER_STATE,*PSYSTEM_POWER_STATE;

#define POWER_SYSTEM_MAXIMUM 7

  typedef enum {
    PowerActionNone = 0, PowerActionReserved, PowerActionSleep, PowerActionHibernate,
    PowerActionShutdown, PowerActionShutdownReset, PowerActionShutdownOff,
    PowerActionWarmEject
  } POWER_ACTION,*PPOWER_ACTION;

  typedef enum _DEVICE_POWER_STATE {
    PowerDeviceUnspecified = 0, PowerDeviceD0, PowerDeviceD1, PowerDeviceD2, PowerDeviceD3,
    PowerDeviceMaximum
  } DEVICE_POWER_STATE,*PDEVICE_POWER_STATE;

  typedef enum _MONITOR_DISPLAY_STATE {
    PowerMonitorOff = 0, PowerMonitorOn, PowerMonitorDim
  } MONITOR_DISPLAY_STATE, *PMONITOR_DISPLAY_STATE;

  typedef enum _USER_ACTIVITY_PRESENCE {
    PowerUserPresent = 0,
    PowerUserNotPresent,
    PowerUserInactive,
    PowerUserMaximum,
    PowerUserInvalid = PowerUserMaximum
  } USER_ACTIVITY_PRESENCE,*PUSER_ACTIVITY_PRESENCE;

#define ES_SYSTEM_REQUIRED ((DWORD)0x00000001)
#define ES_DISPLAY_REQUIRED ((DWORD)0x00000002)
#define ES_USER_PRESENT ((DWORD)0x00000004)
#define ES_AWAYMODE_REQUIRED ((DWORD)0x00000040)
#define ES_CONTINUOUS ((DWORD)0x80000000)

  typedef DWORD EXECUTION_STATE, *PEXECUTION_STATE;

  typedef enum {
    LT_DONT_CARE,LT_LOWEST_LATENCY
  } LATENCY_TIME;

#define DIAGNOSTIC_REASON_VERSION 0
#define POWER_REQUEST_CONTEXT_VERSION 0

#define DIAGNOSTIC_REASON_SIMPLE_STRING 0x00000001
#define DIAGNOSTIC_REASON_DETAILED_STRING 0x00000002
#define DIAGNOSTIC_REASON_NOT_SPECIFIED 0x80000000
#define DIAGNOSTIC_REASON_INVALID_FLAGS (~0x80000003)

#define POWER_REQUEST_CONTEXT_SIMPLE_STRING 0x00000001
#define POWER_REQUEST_CONTEXT_DETAILED_STRING 0x00000002

  typedef enum _POWER_REQUEST_TYPE {
    PowerRequestDisplayRequired,
    PowerRequestSystemRequired,
    PowerRequestAwayModeRequired,
    PowerRequestExecutionRequired
  } POWER_REQUEST_TYPE,*PPOWER_REQUEST_TYPE;

#define PDCAP_D0_SUPPORTED 0x00000001
#define PDCAP_D1_SUPPORTED 0x00000002
#define PDCAP_D2_SUPPORTED 0x00000004
#define PDCAP_D3_SUPPORTED 0x00000008
#define PDCAP_WAKE_FROM_D0_SUPPORTED 0x00000010
#define PDCAP_WAKE_FROM_D1_SUPPORTED 0x00000020
#define PDCAP_WAKE_FROM_D2_SUPPORTED 0x00000040
#define PDCAP_WAKE_FROM_D3_SUPPORTED 0x00000080
#define PDCAP_WARM_EJECT_SUPPORTED 0x00000100

    typedef struct CM_Power_Data_s {
      DWORD PD_Size;
      DEVICE_POWER_STATE PD_MostRecentPowerState;
      DWORD PD_Capabilities;
      DWORD PD_D1Latency;
      DWORD PD_D2Latency;
      DWORD PD_D3Latency;
      DEVICE_POWER_STATE PD_PowerStateMapping[POWER_SYSTEM_MAXIMUM];
      SYSTEM_POWER_STATE PD_DeepestSystemWake;
    } CM_POWER_DATA,*PCM_POWER_DATA;

    typedef enum {
      SystemPowerPolicyAc,
      SystemPowerPolicyDc,
      VerifySystemPolicyAc,
      VerifySystemPolicyDc,
      SystemPowerCapabilities,
      SystemBatteryState,
      SystemPowerStateHandler,
      ProcessorStateHandler,
      SystemPowerPolicyCurrent,
      AdministratorPowerPolicy,
      SystemReserveHiberFile,
      ProcessorInformation,
      SystemPowerInformation,
      ProcessorStateHandler2,
      LastWakeTime,
      LastSleepTime,
      SystemExecutionState,
      SystemPowerStateNotifyHandler,
      ProcessorPowerPolicyAc,
      ProcessorPowerPolicyDc,
      VerifyProcessorPowerPolicyAc,
      VerifyProcessorPowerPolicyDc,
      ProcessorPowerPolicyCurrent,
      SystemPowerStateLogging,
      SystemPowerLoggingEntry,
      SetPowerSettingValue,
      NotifyUserPowerSetting,
      PowerInformationLevelUnused0,
      SystemMonitorHiberBootPowerOff,
      SystemVideoState,
      TraceApplicationPowerMessage,
      TraceApplicationPowerMessageEnd,
      ProcessorPerfStates,
      ProcessorIdleStates,
      ProcessorCap,
      SystemWakeSource,
      SystemHiberFileInformation,
      TraceServicePowerMessage,
      ProcessorLoad,
      PowerShutdownNotification,
      MonitorCapabilities,
      SessionPowerInit,
      SessionDisplayState,
      PowerRequestCreate,
      PowerRequestAction,
      GetPowerRequestList,
      ProcessorInformationEx,
      NotifyUserModeLegacyPowerEvent,
      GroupPark,
      ProcessorIdleDomains,
      WakeTimerList,
      SystemHiberFileSize,
      ProcessorIdleStatesHv,
      ProcessorPerfStatesHv,
      ProcessorPerfCapHv,
      ProcessorSetIdle,
      LogicalProcessorIdling,
      UserPresence,
      PowerSettingNotificationName,
      GetPowerSettingValue,
      IdleResiliency,
      SessionRITState,
      SessionConnectNotification,
      SessionPowerCleanup,
      SessionLockState,
      SystemHiberbootState,
      PlatformInformation,
      PdcInvocation,
      MonitorInvocation,
      FirmwareTableInformationRegistered,
      SetShutdownSelectedTime,
      SuspendResumeInvocation,
      PlmPowerRequestCreate,
      ScreenOff,
      CsDeviceNotification,
      PlatformRole,
      LastResumePerformance,
      DisplayBurst,
      ExitLatencySamplingPercentage,
      ApplyLowPowerScenarioSettings,
      PowerInformationLevelMaximum
    } POWER_INFORMATION_LEVEL;

    typedef enum {
      UserNotPresent = 0,
      UserPresent = 1,
      UserUnknown = 0xff
    } POWER_USER_PRESENCE_TYPE,*PPOWER_USER_PRESENCE_TYPE;

    typedef struct _POWER_USER_PRESENCE {
      POWER_USER_PRESENCE_TYPE UserPresence;
    } POWER_USER_PRESENCE,*PPOWER_USER_PRESENCE;

    typedef struct _POWER_SESSION_CONNECT {
      BOOLEAN Connected;
      BOOLEAN Console;
    } POWER_SESSION_CONNECT,*PPOWER_SESSION_CONNECT;

    typedef struct _POWER_SESSION_TIMEOUTS {
      DWORD InputTimeout;
      DWORD DisplayTimeout;
    } POWER_SESSION_TIMEOUTS,*PPOWER_SESSION_TIMEOUTS;

    typedef struct _POWER_SESSION_RIT_STATE {
      BOOLEAN Active;
      DWORD LastInputTime;
    } POWER_SESSION_RIT_STATE,*PPOWER_SESSION_RIT_STATE;

    typedef struct _POWER_SESSION_WINLOGON {
      DWORD SessionId;
      BOOLEAN Console;
      BOOLEAN Locked;
    } POWER_SESSION_WINLOGON,*PPOWER_SESSION_WINLOGON;

    typedef struct _POWER_IDLE_RESILIENCY {
      DWORD CoalescingTimeout;
      DWORD IdleResiliencyPeriod;
    } POWER_IDLE_RESILIENCY,*PPOWER_IDLE_RESILIENCY;

    typedef enum {
      MonitorRequestReasonUnknown,
      MonitorRequestReasonPowerButton,
      MonitorRequestReasonRemoteConnection,
      MonitorRequestReasonScMonitorpower,
      MonitorRequestReasonUserInput,
      MonitorRequestReasonAcDcDisplayBurst,
      MonitorRequestReasonUserDisplayBurst,
      MonitorRequestReasonPoSetSystemState,
      MonitorRequestReasonSetThreadExecutionState,
      MonitorRequestReasonFullWake,
      MonitorRequestReasonSessionUnlock,
      MonitorRequestReasonScreenOffRequest,
      MonitorRequestReasonIdleTimeout,
      MonitorRequestReasonPolicyChange,
      MonitorRequestReasonMax
    } POWER_MONITOR_REQUEST_REASON;

    typedef struct _POWER_MONITOR_INVOCATION {
      BOOLEAN On;
      BOOLEAN Console;
      POWER_MONITOR_REQUEST_REASON RequestReason;
    } POWER_MONITOR_INVOCATION,*PPOWER_MONITOR_INVOCATION;

    typedef struct _RESUME_PERFORMANCE {
      DWORD PostTimeMs;
      ULONGLONG TotalResumeTimeMs;
      ULONGLONG ResumeCompleteTimestamp;
    } RESUME_PERFORMANCE,*PRESUME_PERFORMANCE;

    typedef enum {
      PoAc,
      PoDc,
      PoHot,
      PoConditionMaximum
    } SYSTEM_POWER_CONDITION;

    typedef struct {
      DWORD Version;
      GUID Guid;
      SYSTEM_POWER_CONDITION PowerCondition;
      DWORD DataLength;
      BYTE Data[ANYSIZE_ARRAY];
    } SET_POWER_SETTING_VALUE,*PSET_POWER_SETTING_VALUE;

#define POWER_SETTING_VALUE_VERSION (0x1)

    typedef struct {
      GUID Guid;
    } NOTIFY_USER_POWER_SETTING,*PNOTIFY_USER_POWER_SETTING;

    typedef struct _APPLICATIONLAUNCH_SETTING_VALUE {
      LARGE_INTEGER ActivationTime;
      DWORD Flags;
      DWORD ButtonInstanceID;
    } APPLICATIONLAUNCH_SETTING_VALUE,*PAPPLICATIONLAUNCH_SETTING_VALUE;

    typedef enum _POWER_PLATFORM_ROLE {
      PlatformRoleUnspecified = 0,
      PlatformRoleDesktop,
      PlatformRoleMobile,
      PlatformRoleWorkstation,
      PlatformRoleEnterpriseServer,
      PlatformRoleSOHOServer,
      PlatformRoleAppliancePC,
      PlatformRolePerformanceServer,
      PlatformRoleSlate,
      PlatformRoleMaximum
    } POWER_PLATFORM_ROLE,*PPOWER_PLATFORM_ROLE;

    typedef struct _POWER_PLATFORM_INFORMATION {
      BOOLEAN AoAc;
    } POWER_PLATFORM_INFORMATION,*PPOWER_PLATFORM_INFORMATION;

#define POWER_PLATFORM_ROLE_V1 (0x00000001)
#define POWER_PLATFORM_ROLE_V1_MAX (PlatformRolePerformanceServer + 1)

#define POWER_PLATFORM_ROLE_V2 (0x00000002)
#define POWER_PLATFORM_ROLE_V2_MAX (PlatformRoleSlate + 1)

#if _WIN32_WINNT >= 0x0602
#define POWER_PLATFORM_ROLE_VERSION POWER_PLATFORM_ROLE_V2
#define POWER_PLATFORM_ROLE_VERSION_MAX POWER_PLATFORM_ROLE_V2_MAX
#else
#define POWER_PLATFORM_ROLE_VERSION POWER_PLATFORM_ROLE_V1
#define POWER_PLATFORM_ROLE_VERSION_MAX POWER_PLATFORM_ROLE_V1_MAX
#endif

    typedef struct {
      DWORD Granularity;
      DWORD Capacity;
    } BATTERY_REPORTING_SCALE,*PBATTERY_REPORTING_SCALE;

    typedef struct {
      DWORD Frequency;
      DWORD Flags;
      DWORD PercentFrequency;
    } PPM_WMI_LEGACY_PERFSTATE,*PPPM_WMI_LEGACY_PERFSTATE;

    typedef struct {
      DWORD Latency;
      DWORD Power;
      DWORD TimeCheck;
      BYTE PromotePercent;
      BYTE DemotePercent;
      BYTE StateType;
      BYTE Reserved;
      DWORD StateFlags;
      DWORD Context;
      DWORD IdleHandler;
      DWORD Reserved1;
    } PPM_WMI_IDLE_STATE,*PPPM_WMI_IDLE_STATE;

    typedef struct {
      DWORD Type;
      DWORD Count;
      DWORD TargetState;
      DWORD OldState;
      DWORD64 TargetProcessors;
      PPM_WMI_IDLE_STATE State[ANYSIZE_ARRAY];
    } PPM_WMI_IDLE_STATES,*PPPM_WMI_IDLE_STATES;

    typedef struct {
      DWORD Type;
      DWORD Count;
      DWORD TargetState;
      DWORD OldState;
      PVOID TargetProcessors;
      PPM_WMI_IDLE_STATE State[ANYSIZE_ARRAY];
    } PPM_WMI_IDLE_STATES_EX,*PPPM_WMI_IDLE_STATES_EX;

    typedef struct {
      DWORD Frequency;
      DWORD Power;
      BYTE PercentFrequency;
      BYTE IncreaseLevel;
      BYTE DecreaseLevel;
      BYTE Type;
      DWORD IncreaseTime;
      DWORD DecreaseTime;
      DWORD64 Control;
      DWORD64 Status;
      DWORD HitCount;
      DWORD Reserved1;
      DWORD64 Reserved2;
      DWORD64 Reserved3;
    } PPM_WMI_PERF_STATE,*PPPM_WMI_PERF_STATE;

    typedef struct {
      DWORD Count;
      DWORD MaxFrequency;
      DWORD CurrentState;
      DWORD MaxPerfState;
      DWORD MinPerfState;
      DWORD LowestPerfState;
      DWORD ThermalConstraint;
      BYTE BusyAdjThreshold;
      BYTE PolicyType;
      BYTE Type;
      BYTE Reserved;
      DWORD TimerInterval;
      DWORD64 TargetProcessors;
      DWORD PStateHandler;
      DWORD PStateContext;
      DWORD TStateHandler;
      DWORD TStateContext;
      DWORD FeedbackHandler;
      DWORD Reserved1;
      DWORD64 Reserved2;
      PPM_WMI_PERF_STATE State[ANYSIZE_ARRAY];
    } PPM_WMI_PERF_STATES,*PPPM_WMI_PERF_STATES;

    typedef struct {
      DWORD Count;
      DWORD MaxFrequency;
      DWORD CurrentState;
      DWORD MaxPerfState;
      DWORD MinPerfState;
      DWORD LowestPerfState;
      DWORD ThermalConstraint;
      BYTE BusyAdjThreshold;
      BYTE PolicyType;
      BYTE Type;
      BYTE Reserved;
      DWORD TimerInterval;
      PVOID TargetProcessors;
      DWORD PStateHandler;
      DWORD PStateContext;
      DWORD TStateHandler;
      DWORD TStateContext;
      DWORD FeedbackHandler;
      DWORD Reserved1;
      DWORD64 Reserved2;
      PPM_WMI_PERF_STATE State[ANYSIZE_ARRAY];
    } PPM_WMI_PERF_STATES_EX,*PPPM_WMI_PERF_STATES_EX;

#define PROC_IDLE_BUCKET_COUNT 6
#define PROC_IDLE_BUCKET_COUNT_EX 16

    typedef struct {
      DWORD IdleTransitions;
      DWORD FailedTransitions;
      DWORD InvalidBucketIndex;
      DWORD64 TotalTime;
      DWORD IdleTimeBuckets[PROC_IDLE_BUCKET_COUNT];
    } PPM_IDLE_STATE_ACCOUNTING,*PPPM_IDLE_STATE_ACCOUNTING;

    typedef struct {
      DWORD StateCount;
      DWORD TotalTransitions;
      DWORD ResetCount;
      DWORD64 StartTime;
      PPM_IDLE_STATE_ACCOUNTING State[ANYSIZE_ARRAY];
    } PPM_IDLE_ACCOUNTING,*PPPM_IDLE_ACCOUNTING;

    typedef struct {
      DWORD64 TotalTimeUs;
      DWORD MinTimeUs;
      DWORD MaxTimeUs;
      DWORD Count;
    } PPM_IDLE_STATE_BUCKET_EX,*PPPM_IDLE_STATE_BUCKET_EX;

    typedef struct {
      DWORD64 TotalTime;
      DWORD IdleTransitions;
      DWORD FailedTransitions;
      DWORD InvalidBucketIndex;
      DWORD MinTimeUs;
      DWORD MaxTimeUs;
      DWORD CancelledTransitions;
      PPM_IDLE_STATE_BUCKET_EX IdleTimeBuckets[PROC_IDLE_BUCKET_COUNT_EX];
    } PPM_IDLE_STATE_ACCOUNTING_EX,*PPPM_IDLE_STATE_ACCOUNTING_EX;

    typedef struct {
      DWORD StateCount;
      DWORD TotalTransitions;
      DWORD ResetCount;
      DWORD AbortCount;
      DWORD64 StartTime;
      PPM_IDLE_STATE_ACCOUNTING_EX State[ANYSIZE_ARRAY];
    } PPM_IDLE_ACCOUNTING_EX,*PPPM_IDLE_ACCOUNTING_EX;

#define ACPI_PPM_SOFTWARE_ALL 0xfc
#define ACPI_PPM_SOFTWARE_ANY 0xfd
#define ACPI_PPM_HARDWARE_ALL 0xfe

#define MS_PPM_SOFTWARE_ALL 0x1

#define PPM_FIRMWARE_ACPI1C2 0x1
#define PPM_FIRMWARE_ACPI1C3 0x2
#define PPM_FIRMWARE_ACPI1TSTATES 0x4
#define PPM_FIRMWARE_CST 0x8
#define PPM_FIRMWARE_CSD 0x10
#define PPM_FIRMWARE_PCT 0x20
#define PPM_FIRMWARE_PSS 0x40
#define PPM_FIRMWARE_XPSS 0x80
#define PPM_FIRMWARE_PPC 0x100
#define PPM_FIRMWARE_PSD 0x200
#define PPM_FIRMWARE_PTC 0x400
#define PPM_FIRMWARE_TSS 0x800
#define PPM_FIRMWARE_TPC 0x1000
#define PPM_FIRMWARE_TSD 0x2000
#define PPM_FIRMWARE_PCCH 0x4000
#define PPM_FIRMWARE_PCCP 0x8000
#define PPM_FIRMWARE_OSC 0x10000
#define PPM_FIRMWARE_PDC 0x20000
#define PPM_FIRMWARE_CPC 0x40000

#define PPM_PERFORMANCE_IMPLEMENTATION_NONE 0
#define PPM_PERFORMANCE_IMPLEMENTATION_PSTATES 1
#define PPM_PERFORMANCE_IMPLEMENTATION_PCCV1 2
#define PPM_PERFORMANCE_IMPLEMENTATION_CPPC 3
#define PPM_PERFORMANCE_IMPLEMENTATION_PEP 4

#define PPM_IDLE_IMPLEMENTATION_NONE 0x0
#define PPM_IDLE_IMPLEMENTATION_CSTATES 0x1
#define PPM_IDLE_IMPLEMENTATION_PEP 0x2

    typedef struct {
      DWORD State;
      DWORD Status;
      DWORD Latency;
      DWORD Speed;
      DWORD Processor;
    } PPM_PERFSTATE_EVENT,*PPPM_PERFSTATE_EVENT;

    typedef struct {
      DWORD State;
      DWORD Latency;
      DWORD Speed;
      DWORD64 Processors;
    } PPM_PERFSTATE_DOMAIN_EVENT,*PPPM_PERFSTATE_DOMAIN_EVENT;

    typedef struct {
      DWORD NewState;
      DWORD OldState;
      DWORD64 Processors;
    } PPM_IDLESTATE_EVENT,*PPPM_IDLESTATE_EVENT;

    typedef struct {
      DWORD ThermalConstraint;
      DWORD64 Processors;
    } PPM_THERMALCHANGE_EVENT,*PPPM_THERMALCHANGE_EVENT;
    typedef struct {
      BYTE Mode;
      DWORD64 Processors;
    } PPM_THERMAL_POLICY_EVENT,*PPPM_THERMAL_POLICY_EVENT;

    DEFINE_GUID (PPM_PERFSTATE_CHANGE_GUID, 0xa5b32ddd, 0x7f39, 0x4abc, 0xb8, 0x92, 0x90, 0xe, 0x43, 0xb5, 0x9e, 0xbb);
    DEFINE_GUID (PPM_PERFSTATE_DOMAIN_CHANGE_GUID, 0x995e6b7f, 0xd653, 0x497a, 0xb9, 0x78, 0x36, 0xa3, 0xc, 0x29, 0xbf, 0x1);
    DEFINE_GUID (PPM_IDLESTATE_CHANGE_GUID, 0x4838fe4f, 0xf71c, 0x4e51, 0x9e, 0xcc, 0x84, 0x30, 0xa7, 0xac, 0x4c, 0x6c);
    DEFINE_GUID (PPM_PERFSTATES_DATA_GUID, 0x5708cc20, 0x7d40, 0x4bf4, 0xb4, 0xaa, 0x2b, 0x01, 0x33, 0x8d, 0x01, 0x26);
    DEFINE_GUID (PPM_IDLESTATES_DATA_GUID, 0xba138e10, 0xe250, 0x4ad7, 0x86, 0x16, 0xcf, 0x1a, 0x7a, 0xd4, 0x10, 0xe7);
    DEFINE_GUID (PPM_IDLE_ACCOUNTING_GUID, 0xe2a26f78, 0xae07, 0x4ee0, 0xa3, 0x0f, 0xce, 0x54, 0xf5, 0x5a, 0x94, 0xcd);
    DEFINE_GUID (PPM_IDLE_ACCOUNTING_EX_GUID, 0xd67abd39, 0x81f8, 0x4a5e, 0x81, 0x52, 0x72, 0xe3, 0x1e, 0xc9, 0x12, 0xee);
    DEFINE_GUID (PPM_THERMALCONSTRAINT_GUID, 0xa852c2c8, 0x1a4c, 0x423b, 0x8c, 0x2c, 0xf3, 0x0d, 0x82, 0x93, 0x1a, 0x88);
    DEFINE_GUID (PPM_PERFMON_PERFSTATE_GUID, 0x7fd18652, 0xcfe, 0x40d2, 0xb0, 0xa1, 0xb, 0x6, 0x6a, 0x87, 0x75, 0x9e);
    DEFINE_GUID (PPM_THERMAL_POLICY_CHANGE_GUID, 0x48f377b8, 0x6880, 0x4c7b, 0x8b, 0xdc, 0x38, 0x1, 0x76, 0xc6, 0x65, 0x4d);

    typedef struct {
      POWER_ACTION Action;
      DWORD Flags;
      DWORD EventCode;
    } POWER_ACTION_POLICY,*PPOWER_ACTION_POLICY;

#define POWER_ACTION_QUERY_ALLOWED 0x00000001
#define POWER_ACTION_UI_ALLOWED 0x00000002
#define POWER_ACTION_OVERRIDE_APPS 0x00000004
#define POWER_ACTION_HIBERBOOT 0x00000008
#define POWER_ACTION_PSEUDO_TRANSITION 0x08000000
#define POWER_ACTION_LIGHTEST_FIRST 0x10000000
#define POWER_ACTION_LOCK_CONSOLE 0x20000000
#define POWER_ACTION_DISABLE_WAKES 0x40000000
#define POWER_ACTION_CRITICAL 0x80000000

#define POWER_LEVEL_USER_NOTIFY_TEXT 0x00000001
#define POWER_LEVEL_USER_NOTIFY_SOUND 0x00000002
#define POWER_LEVEL_USER_NOTIFY_EXEC 0x00000004
#define POWER_USER_NOTIFY_BUTTON 0x00000008
#define POWER_USER_NOTIFY_SHUTDOWN 0x00000010
#define POWER_USER_NOTIFY_FORCED_SHUTDOWN 0x00000020
#define POWER_FORCE_TRIGGER_RESET 0x80000000

#define BATTERY_DISCHARGE_FLAGS_EVENTCODE_MASK 0x00000007
#define BATTERY_DISCHARGE_FLAGS_ENABLE 0x80000000

#define DISCHARGE_POLICY_CRITICAL 0
#define DISCHARGE_POLICY_LOW 1

#define NUM_DISCHARGE_POLICIES 4

#define PROCESSOR_IDLESTATE_POLICY_COUNT 0x3

    typedef struct {
      DWORD TimeCheck;
      BYTE DemotePercent;
      BYTE PromotePercent;
      BYTE Spare[2];
    } PROCESSOR_IDLESTATE_INFO,*PPROCESSOR_IDLESTATE_INFO;

    typedef struct {
      BOOLEAN Enable;
      BYTE Spare[3];
      DWORD BatteryLevel;
      POWER_ACTION_POLICY PowerPolicy;
      SYSTEM_POWER_STATE MinSystemState;
    } SYSTEM_POWER_LEVEL,*PSYSTEM_POWER_LEVEL;

    typedef struct _SYSTEM_POWER_POLICY {
      DWORD Revision;
      POWER_ACTION_POLICY PowerButton;
      POWER_ACTION_POLICY SleepButton;
      POWER_ACTION_POLICY LidClose;
      SYSTEM_POWER_STATE LidOpenWake;
      DWORD Reserved;
      POWER_ACTION_POLICY Idle;
      DWORD IdleTimeout;
      BYTE IdleSensitivity;
      BYTE DynamicThrottle;
      BYTE Spare2[2];
      SYSTEM_POWER_STATE MinSleep;
      SYSTEM_POWER_STATE MaxSleep;
      SYSTEM_POWER_STATE ReducedLatencySleep;
      DWORD WinLogonFlags;
      DWORD Spare3;
      DWORD DozeS4Timeout;
      DWORD BroadcastCapacityResolution;
      SYSTEM_POWER_LEVEL DischargePolicy[NUM_DISCHARGE_POLICIES];
      DWORD VideoTimeout;
      BOOLEAN VideoDimDisplay;
      DWORD VideoReserved[3];
      DWORD SpindownTimeout;
      BOOLEAN OptimizeForPower;
      BYTE FanThrottleTolerance;
      BYTE ForcedThrottle;
      BYTE MinThrottle;
      POWER_ACTION_POLICY OverThrottled;
    } SYSTEM_POWER_POLICY,*PSYSTEM_POWER_POLICY;

#define PO_THROTTLE_NONE 0
#define PO_THROTTLE_CONSTANT 1
#define PO_THROTTLE_DEGRADE 2
#define PO_THROTTLE_ADAPTIVE 3
#define PO_THROTTLE_MAXIMUM 4

    typedef struct {
      WORD Revision;
      union {
	WORD AsWORD;
	__C89_NAMELESS struct {
	  WORD AllowScaling : 1;
	  WORD Disabled : 1;
	  WORD Reserved : 14;
	} DUMMYSTRUCTNAME;
      } Flags;
      DWORD PolicyCount;
      PROCESSOR_IDLESTATE_INFO Policy[PROCESSOR_IDLESTATE_POLICY_COUNT];
    } PROCESSOR_IDLESTATE_POLICY,*PPROCESSOR_IDLESTATE_POLICY;

    typedef struct _PROCESSOR_POWER_POLICY_INFO {
      DWORD TimeCheck;
      DWORD DemoteLimit;
      DWORD PromoteLimit;
      BYTE DemotePercent;
      BYTE PromotePercent;
      BYTE Spare[2];
      DWORD AllowDemotion:1;
      DWORD AllowPromotion:1;
      DWORD Reserved:30;
    } PROCESSOR_POWER_POLICY_INFO,*PPROCESSOR_POWER_POLICY_INFO;

    typedef struct _PROCESSOR_POWER_POLICY {
      DWORD Revision;
      BYTE DynamicThrottle;
      BYTE Spare[3];
      DWORD DisableCStates:1;
      DWORD Reserved:31;
      DWORD PolicyCount;
      PROCESSOR_POWER_POLICY_INFO Policy[3];
    } PROCESSOR_POWER_POLICY,*PPROCESSOR_POWER_POLICY;

    typedef struct {
      DWORD Revision;
      BYTE MaxThrottle;
      BYTE MinThrottle;
      BYTE BusyAdjThreshold;
      __C89_NAMELESS union {
	BYTE Spare;
	union {
	  BYTE AsBYTE;
	  __C89_NAMELESS struct {
	    BYTE NoDomainAccounting : 1;
	    BYTE IncreasePolicy: 2;
	    BYTE DecreasePolicy: 2;
	    BYTE Reserved : 3;
	  } DUMMYSTRUCTNAME;
	} Flags;
      } DUMMYUNIONNAME;
      DWORD TimeCheck;
      DWORD IncreaseTime;
      DWORD DecreaseTime;
      DWORD IncreasePercent;
      DWORD DecreasePercent;
    } PROCESSOR_PERFSTATE_POLICY,*PPROCESSOR_PERFSTATE_POLICY;

    typedef struct _ADMINISTRATOR_POWER_POLICY {
      SYSTEM_POWER_STATE MinSleep;
      SYSTEM_POWER_STATE MaxSleep;
      DWORD MinVideoTimeout;
      DWORD MaxVideoTimeout;
      DWORD MinSpindownTimeout;
      DWORD MaxSpindownTimeout;
    } ADMINISTRATOR_POWER_POLICY,*PADMINISTRATOR_POWER_POLICY;

    typedef struct {
      BOOLEAN PowerButtonPresent;
      BOOLEAN SleepButtonPresent;
      BOOLEAN LidPresent;
      BOOLEAN SystemS1;
      BOOLEAN SystemS2;
      BOOLEAN SystemS3;
      BOOLEAN SystemS4;
      BOOLEAN SystemS5;
      BOOLEAN HiberFilePresent;
      BOOLEAN FullWake;
      BOOLEAN VideoDimPresent;
      BOOLEAN ApmPresent;
      BOOLEAN UpsPresent;
      BOOLEAN ThermalControl;
      BOOLEAN ProcessorThrottle;
      BYTE ProcessorMinThrottle;
      BYTE ProcessorMaxThrottle;
      BOOLEAN FastSystemS4;
      BYTE spare2[3];
      BOOLEAN DiskSpinDown;
      BYTE spare3[8];
      BOOLEAN SystemBatteriesPresent;
      BOOLEAN BatteriesAreShortTerm;
      BATTERY_REPORTING_SCALE BatteryScale[3];
      SYSTEM_POWER_STATE AcOnLineWake;
      SYSTEM_POWER_STATE SoftLidWake;
      SYSTEM_POWER_STATE RtcWake;
      SYSTEM_POWER_STATE MinDeviceWakeState;
      SYSTEM_POWER_STATE DefaultLowLatencyWake;
    } SYSTEM_POWER_CAPABILITIES,*PSYSTEM_POWER_CAPABILITIES;

    typedef struct {
      BOOLEAN AcOnLine;
      BOOLEAN BatteryPresent;
      BOOLEAN Charging;
      BOOLEAN Discharging;
      BOOLEAN Spare1[4];
      DWORD MaxCapacity;
      DWORD RemainingCapacity;
      DWORD Rate;
      DWORD EstimatedTime;
      DWORD DefaultAlert1;
      DWORD DefaultAlert2;
    } SYSTEM_BATTERY_STATE,*PSYSTEM_BATTERY_STATE;

#include "pshpack4.h"

#define IMAGE_DOS_SIGNATURE 0x5A4D
#define IMAGE_OS2_SIGNATURE 0x454E
#define IMAGE_OS2_SIGNATURE_LE 0x454C
#define IMAGE_VXD_SIGNATURE 0x454C
#define IMAGE_NT_SIGNATURE 0x00004550

#include "pshpack2.h"

    typedef struct _IMAGE_DOS_HEADER {
      WORD e_magic;
      WORD e_cblp;
      WORD e_cp;
      WORD e_crlc;
      WORD e_cparhdr;
      WORD e_minalloc;
      WORD e_maxalloc;
      WORD e_ss;
      WORD e_sp;
      WORD e_csum;
      WORD e_ip;
      WORD e_cs;
      WORD e_lfarlc;
      WORD e_ovno;
      WORD e_res[4];
      WORD e_oemid;
      WORD e_oeminfo;
      WORD e_res2[10];
      LONG e_lfanew;
    } IMAGE_DOS_HEADER,*PIMAGE_DOS_HEADER;

    typedef struct _IMAGE_OS2_HEADER {
      WORD ne_magic;
      CHAR ne_ver;
      CHAR ne_rev;
      WORD ne_enttab;
      WORD ne_cbenttab;
      LONG ne_crc;
      WORD ne_flags;
      WORD ne_autodata;
      WORD ne_heap;
      WORD ne_stack;
      LONG ne_csip;
      LONG ne_sssp;
      WORD ne_cseg;
      WORD ne_cmod;
      WORD ne_cbnrestab;
      WORD ne_segtab;
      WORD ne_rsrctab;
      WORD ne_restab;
      WORD ne_modtab;
      WORD ne_imptab;
      LONG ne_nrestab;
      WORD ne_cmovent;
      WORD ne_align;
      WORD ne_cres;
      BYTE ne_exetyp;
      BYTE ne_flagsothers;
      WORD ne_pretthunks;
      WORD ne_psegrefbytes;
      WORD ne_swaparea;
      WORD ne_expver;
    } IMAGE_OS2_HEADER,*PIMAGE_OS2_HEADER;

    typedef struct _IMAGE_VXD_HEADER {
      WORD e32_magic;
      BYTE e32_border;
      BYTE e32_worder;
      DWORD e32_level;
      WORD e32_cpu;
      WORD e32_os;
      DWORD e32_ver;
      DWORD e32_mflags;
      DWORD e32_mpages;
      DWORD e32_startobj;
      DWORD e32_eip;
      DWORD e32_stackobj;
      DWORD e32_esp;
      DWORD e32_pagesize;
      DWORD e32_lastpagesize;
      DWORD e32_fixupsize;
      DWORD e32_fixupsum;
      DWORD e32_ldrsize;
      DWORD e32_ldrsum;
      DWORD e32_objtab;
      DWORD e32_objcnt;
      DWORD e32_objmap;
      DWORD e32_itermap;
      DWORD e32_rsrctab;
      DWORD e32_rsrccnt;
      DWORD e32_restab;
      DWORD e32_enttab;
      DWORD e32_dirtab;
      DWORD e32_dircnt;
      DWORD e32_fpagetab;
      DWORD e32_frectab;
      DWORD e32_impmod;
      DWORD e32_impmodcnt;
      DWORD e32_impproc;
      DWORD e32_pagesum;
      DWORD e32_datapage;
      DWORD e32_preload;
      DWORD e32_nrestab;
      DWORD e32_cbnrestab;
      DWORD e32_nressum;
      DWORD e32_autodata;
      DWORD e32_debuginfo;
      DWORD e32_debuglen;
      DWORD e32_instpreload;
      DWORD e32_instdemand;
      DWORD e32_heapsize;
      BYTE e32_res3[12];
      DWORD e32_winresoff;
      DWORD e32_winreslen;
      WORD e32_devid;
      WORD e32_ddkver;
    } IMAGE_VXD_HEADER,*PIMAGE_VXD_HEADER;

#include "poppack.h"

    typedef struct _IMAGE_FILE_HEADER {
      WORD Machine;
      WORD NumberOfSections;
      DWORD TimeDateStamp;
      DWORD PointerToSymbolTable;
      DWORD NumberOfSymbols;
      WORD SizeOfOptionalHeader;
      WORD Characteristics;
    } IMAGE_FILE_HEADER,*PIMAGE_FILE_HEADER;

#define IMAGE_SIZEOF_FILE_HEADER 20

#define IMAGE_FILE_RELOCS_STRIPPED 0x0001
#define IMAGE_FILE_EXECUTABLE_IMAGE 0x0002
#define IMAGE_FILE_LINE_NUMS_STRIPPED 0x0004
#define IMAGE_FILE_LOCAL_SYMS_STRIPPED 0x0008
#define IMAGE_FILE_AGGRESIVE_WS_TRIM 0x0010
#define IMAGE_FILE_LARGE_ADDRESS_AWARE 0x0020
#define IMAGE_FILE_BYTES_REVERSED_LO 0x0080
#define IMAGE_FILE_32BIT_MACHINE 0x0100
#define IMAGE_FILE_DEBUG_STRIPPED 0x0200
#define IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP 0x0400
#define IMAGE_FILE_NET_RUN_FROM_SWAP 0x0800
#define IMAGE_FILE_SYSTEM 0x1000
#define IMAGE_FILE_DLL 0x2000
#define IMAGE_FILE_UP_SYSTEM_ONLY 0x4000
#define IMAGE_FILE_BYTES_REVERSED_HI 0x8000

#define IMAGE_FILE_MACHINE_UNKNOWN 0
#define IMAGE_FILE_MACHINE_I386 0x014c
#define IMAGE_FILE_MACHINE_R3000 0x0162
#define IMAGE_FILE_MACHINE_R4000 0x0166
#define IMAGE_FILE_MACHINE_R10000 0x0168
#define IMAGE_FILE_MACHINE_WCEMIPSV2 0x0169
#define IMAGE_FILE_MACHINE_ALPHA 0x0184
#define IMAGE_FILE_MACHINE_SH3 0x01a2
#define IMAGE_FILE_MACHINE_SH3DSP 0x01a3
#define IMAGE_FILE_MACHINE_SH3E 0x01a4
#define IMAGE_FILE_MACHINE_SH4 0x01a6
#define IMAGE_FILE_MACHINE_SH5 0x01a8
#define IMAGE_FILE_MACHINE_ARM 0x01c0
#define IMAGE_FILE_MACHINE_ARMV7 0x01c4
#define IMAGE_FILE_MACHINE_ARMNT 0x01c4
#define IMAGE_FILE_MACHINE_ARM64 0xaa64
#define IMAGE_FILE_MACHINE_THUMB 0x01c2
#define IMAGE_FILE_MACHINE_AM33 0x01d3
#define IMAGE_FILE_MACHINE_POWERPC 0x01F0
#define IMAGE_FILE_MACHINE_POWERPCFP 0x01f1
#define IMAGE_FILE_MACHINE_IA64 0x0200
#define IMAGE_FILE_MACHINE_MIPS16 0x0266
#define IMAGE_FILE_MACHINE_ALPHA64 0x0284
#define IMAGE_FILE_MACHINE_MIPSFPU 0x0366
#define IMAGE_FILE_MACHINE_MIPSFPU16 0x0466
#define IMAGE_FILE_MACHINE_AXP64 IMAGE_FILE_MACHINE_ALPHA64
#define IMAGE_FILE_MACHINE_TRICORE 0x0520
#define IMAGE_FILE_MACHINE_CEF 0x0CEF
#define IMAGE_FILE_MACHINE_EBC 0x0EBC
#define IMAGE_FILE_MACHINE_AMD64 0x8664
#define IMAGE_FILE_MACHINE_M32R 0x9041
#define IMAGE_FILE_MACHINE_CEE 0xc0ee

    typedef struct _IMAGE_DATA_DIRECTORY {
      DWORD VirtualAddress;
      DWORD Size;
    } IMAGE_DATA_DIRECTORY,*PIMAGE_DATA_DIRECTORY;

#define IMAGE_NUMBEROF_DIRECTORY_ENTRIES 16

    typedef struct _IMAGE_OPTIONAL_HEADER {

      WORD Magic;
      BYTE MajorLinkerVersion;
      BYTE MinorLinkerVersion;
      DWORD SizeOfCode;
      DWORD SizeOfInitializedData;
      DWORD SizeOfUninitializedData;
      DWORD AddressOfEntryPoint;
      DWORD BaseOfCode;
      DWORD BaseOfData;
      DWORD ImageBase;
      DWORD SectionAlignment;
      DWORD FileAlignment;
      WORD MajorOperatingSystemVersion;
      WORD MinorOperatingSystemVersion;
      WORD MajorImageVersion;
      WORD MinorImageVersion;
      WORD MajorSubsystemVersion;
      WORD MinorSubsystemVersion;
      DWORD Win32VersionValue;
      DWORD SizeOfImage;
      DWORD SizeOfHeaders;
      DWORD CheckSum;
      WORD Subsystem;
      WORD DllCharacteristics;
      DWORD SizeOfStackReserve;
      DWORD SizeOfStackCommit;
      DWORD SizeOfHeapReserve;
      DWORD SizeOfHeapCommit;
      DWORD LoaderFlags;
      DWORD NumberOfRvaAndSizes;
      IMAGE_DATA_DIRECTORY DataDirectory[IMAGE_NUMBEROF_DIRECTORY_ENTRIES];
    } IMAGE_OPTIONAL_HEADER32,*PIMAGE_OPTIONAL_HEADER32;

    typedef struct _IMAGE_ROM_OPTIONAL_HEADER {
      WORD Magic;
      BYTE MajorLinkerVersion;
      BYTE MinorLinkerVersion;
      DWORD SizeOfCode;
      DWORD SizeOfInitializedData;
      DWORD SizeOfUninitializedData;
      DWORD AddressOfEntryPoint;
      DWORD BaseOfCode;
      DWORD BaseOfData;
      DWORD BaseOfBss;
      DWORD GprMask;
      DWORD CprMask[4];
      DWORD GpValue;
    } IMAGE_ROM_OPTIONAL_HEADER,*PIMAGE_ROM_OPTIONAL_HEADER;

    typedef struct _IMAGE_OPTIONAL_HEADER64 {
      WORD Magic;
      BYTE MajorLinkerVersion;
      BYTE MinorLinkerVersion;
      DWORD SizeOfCode;
      DWORD SizeOfInitializedData;
      DWORD SizeOfUninitializedData;
      DWORD AddressOfEntryPoint;
      DWORD BaseOfCode;
      ULONGLONG ImageBase;
      DWORD SectionAlignment;
      DWORD FileAlignment;
      WORD MajorOperatingSystemVersion;
      WORD MinorOperatingSystemVersion;
      WORD MajorImageVersion;
      WORD MinorImageVersion;
      WORD MajorSubsystemVersion;
      WORD MinorSubsystemVersion;
      DWORD Win32VersionValue;
      DWORD SizeOfImage;
      DWORD SizeOfHeaders;
      DWORD CheckSum;
      WORD Subsystem;
      WORD DllCharacteristics;
      ULONGLONG SizeOfStackReserve;
      ULONGLONG SizeOfStackCommit;
      ULONGLONG SizeOfHeapReserve;
      ULONGLONG SizeOfHeapCommit;
      DWORD LoaderFlags;
      DWORD NumberOfRvaAndSizes;
      IMAGE_DATA_DIRECTORY DataDirectory[IMAGE_NUMBEROF_DIRECTORY_ENTRIES];
    } IMAGE_OPTIONAL_HEADER64,*PIMAGE_OPTIONAL_HEADER64;

#define IMAGE_SIZEOF_ROM_OPTIONAL_HEADER 56
#define IMAGE_SIZEOF_STD_OPTIONAL_HEADER 28
#define IMAGE_SIZEOF_NT_OPTIONAL32_HEADER 224
#define IMAGE_SIZEOF_NT_OPTIONAL64_HEADER 240

#define IMAGE_NT_OPTIONAL_HDR32_MAGIC 0x10b
#define IMAGE_NT_OPTIONAL_HDR64_MAGIC 0x20b
#define IMAGE_ROM_OPTIONAL_HDR_MAGIC 0x107

#ifdef _WIN64
    typedef IMAGE_OPTIONAL_HEADER64 IMAGE_OPTIONAL_HEADER;
    typedef PIMAGE_OPTIONAL_HEADER64 PIMAGE_OPTIONAL_HEADER;
#define IMAGE_SIZEOF_NT_OPTIONAL_HEADER IMAGE_SIZEOF_NT_OPTIONAL64_HEADER
#define IMAGE_NT_OPTIONAL_HDR_MAGIC IMAGE_NT_OPTIONAL_HDR64_MAGIC
#else  /* _WIN64 */
    typedef IMAGE_OPTIONAL_HEADER32 IMAGE_OPTIONAL_HEADER;
    typedef PIMAGE_OPTIONAL_HEADER32 PIMAGE_OPTIONAL_HEADER;
#define IMAGE_SIZEOF_NT_OPTIONAL_HEADER IMAGE_SIZEOF_NT_OPTIONAL32_HEADER
#define IMAGE_NT_OPTIONAL_HDR_MAGIC IMAGE_NT_OPTIONAL_HDR32_MAGIC
#endif /* _WIN64 */

    typedef struct _IMAGE_NT_HEADERS64 {
      DWORD Signature;
      IMAGE_FILE_HEADER FileHeader;
      IMAGE_OPTIONAL_HEADER64 OptionalHeader;
    } IMAGE_NT_HEADERS64,*PIMAGE_NT_HEADERS64;

    typedef struct _IMAGE_NT_HEADERS {
      DWORD Signature;
      IMAGE_FILE_HEADER FileHeader;
      IMAGE_OPTIONAL_HEADER32 OptionalHeader;
    } IMAGE_NT_HEADERS32,*PIMAGE_NT_HEADERS32;

    typedef struct _IMAGE_ROM_HEADERS {
      IMAGE_FILE_HEADER FileHeader;
      IMAGE_ROM_OPTIONAL_HEADER OptionalHeader;
    } IMAGE_ROM_HEADERS,*PIMAGE_ROM_HEADERS;

#ifdef _WIN64
    typedef IMAGE_NT_HEADERS64 IMAGE_NT_HEADERS;
    typedef PIMAGE_NT_HEADERS64 PIMAGE_NT_HEADERS;
#else  /* _WIN64 */
    typedef IMAGE_NT_HEADERS32 IMAGE_NT_HEADERS;
    typedef PIMAGE_NT_HEADERS32 PIMAGE_NT_HEADERS;
#endif /* _WIN64 */

#define IMAGE_FIRST_SECTION(ntheader) ((PIMAGE_SECTION_HEADER) ((ULONG_PTR)ntheader + FIELD_OFFSET(IMAGE_NT_HEADERS,OptionalHeader) + ((PIMAGE_NT_HEADERS)(ntheader))->FileHeader.SizeOfOptionalHeader))

#define IMAGE_SUBSYSTEM_UNKNOWN 0
#define IMAGE_SUBSYSTEM_NATIVE 1
#define IMAGE_SUBSYSTEM_WINDOWS_GUI 2
#define IMAGE_SUBSYSTEM_WINDOWS_CUI 3
#define IMAGE_SUBSYSTEM_OS2_CUI 5
#define IMAGE_SUBSYSTEM_POSIX_CUI 7
#define IMAGE_SUBSYSTEM_NATIVE_WINDOWS 8
#define IMAGE_SUBSYSTEM_WINDOWS_CE_GUI 9
#define IMAGE_SUBSYSTEM_EFI_APPLICATION 10
#define IMAGE_SUBSYSTEM_EFI_BOOT_SERVICE_DRIVER 11
#define IMAGE_SUBSYSTEM_EFI_RUNTIME_DRIVER 12
#define IMAGE_SUBSYSTEM_EFI_ROM 13
#define IMAGE_SUBSYSTEM_XBOX 14
#define IMAGE_SUBSYSTEM_WINDOWS_BOOT_APPLICATION 16

#define IMAGE_DLLCHARACTERISTICS_HIGH_ENTROPY_VA 0x0020
#define IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE 0x0040
#define IMAGE_DLLCHARACTERISTICS_FORCE_INTEGRITY 0x0080
#define IMAGE_DLLCHARACTERISTICS_NX_COMPAT 0x0100
#define IMAGE_DLLCHARACTERISTICS_NO_ISOLATION 0x0200
#define IMAGE_DLLCHARACTERISTICS_NO_SEH 0x0400
#define IMAGE_DLLCHARACTERISTICS_NO_BIND 0x0800
#define IMAGE_DLLCHARACTERISTICS_APPCONTAINER 0x1000
#define IMAGE_DLLCHARACTERISTICS_WDM_DRIVER 0x2000
#define IMAGE_DLLCHARACTERISTICS_GUARD_CF 0x4000
#define IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE 0x8000

#define IMAGE_DIRECTORY_ENTRY_EXPORT 0
#define IMAGE_DIRECTORY_ENTRY_IMPORT 1
#define IMAGE_DIRECTORY_ENTRY_RESOURCE 2
#define IMAGE_DIRECTORY_ENTRY_EXCEPTION 3
#define IMAGE_DIRECTORY_ENTRY_SECURITY 4
#define IMAGE_DIRECTORY_ENTRY_BASERELOC 5
#define IMAGE_DIRECTORY_ENTRY_DEBUG 6
#define IMAGE_DIRECTORY_ENTRY_ARCHITECTURE 7
#define IMAGE_DIRECTORY_ENTRY_GLOBALPTR 8
#define IMAGE_DIRECTORY_ENTRY_TLS 9
#define IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG 10
#define IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT 11
#define IMAGE_DIRECTORY_ENTRY_IAT 12
#define IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT 13
#define IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR 14

    typedef struct ANON_OBJECT_HEADER {
      WORD Sig1;
      WORD Sig2;
      WORD Version;
      WORD Machine;
      DWORD TimeDateStamp;
      CLSID ClassID;
      DWORD SizeOfData;
    } ANON_OBJECT_HEADER;

    typedef struct ANON_OBJECT_HEADER_V2 {
      WORD Sig1;
      WORD Sig2;
      WORD Version;
      WORD Machine;
      DWORD TimeDateStamp;
      CLSID ClassID;
      DWORD SizeOfData;
      DWORD Flags;
      DWORD MetaDataSize;
      DWORD MetaDataOffset;
    } ANON_OBJECT_HEADER_V2;

    typedef struct ANON_OBJECT_HEADER_BIGOBJ {
      WORD Sig1;
      WORD Sig2;
      WORD Version;
      WORD Machine;
      DWORD TimeDateStamp;
      CLSID ClassID;
      DWORD SizeOfData;
      DWORD Flags;
      DWORD MetaDataSize;
      DWORD MetaDataOffset;
      DWORD NumberOfSections;
      DWORD PointerToSymbolTable;
      DWORD NumberOfSymbols;
    } ANON_OBJECT_HEADER_BIGOBJ;

#define IMAGE_SIZEOF_SHORT_NAME 8

    typedef struct _IMAGE_SECTION_HEADER {
      BYTE Name[IMAGE_SIZEOF_SHORT_NAME];
      union {
	DWORD PhysicalAddress;
	DWORD VirtualSize;
      } Misc;
      DWORD VirtualAddress;
      DWORD SizeOfRawData;
      DWORD PointerToRawData;
      DWORD PointerToRelocations;
      DWORD PointerToLinenumbers;
      WORD NumberOfRelocations;
      WORD NumberOfLinenumbers;
      DWORD Characteristics;
    } IMAGE_SECTION_HEADER,*PIMAGE_SECTION_HEADER;

#define IMAGE_SIZEOF_SECTION_HEADER 40

#define IMAGE_SCN_TYPE_NO_PAD 0x00000008

#define IMAGE_SCN_CNT_CODE 0x00000020
#define IMAGE_SCN_CNT_INITIALIZED_DATA 0x00000040
#define IMAGE_SCN_CNT_UNINITIALIZED_DATA 0x00000080
#define IMAGE_SCN_LNK_OTHER 0x00000100
#define IMAGE_SCN_LNK_INFO 0x00000200
#define IMAGE_SCN_LNK_REMOVE 0x00000800
#define IMAGE_SCN_LNK_COMDAT 0x00001000
#define IMAGE_SCN_NO_DEFER_SPEC_EXC 0x00004000
#define IMAGE_SCN_GPREL 0x00008000
#define IMAGE_SCN_MEM_FARDATA 0x00008000
#define IMAGE_SCN_MEM_PURGEABLE 0x00020000
#define IMAGE_SCN_MEM_16BIT 0x00020000
#define IMAGE_SCN_MEM_LOCKED 0x00040000
#define IMAGE_SCN_MEM_PRELOAD 0x00080000

#define IMAGE_SCN_ALIGN_1BYTES 0x00100000
#define IMAGE_SCN_ALIGN_2BYTES 0x00200000
#define IMAGE_SCN_ALIGN_4BYTES 0x00300000
#define IMAGE_SCN_ALIGN_8BYTES 0x00400000
#define IMAGE_SCN_ALIGN_16BYTES 0x00500000
#define IMAGE_SCN_ALIGN_32BYTES 0x00600000
#define IMAGE_SCN_ALIGN_64BYTES 0x00700000
#define IMAGE_SCN_ALIGN_128BYTES 0x00800000
#define IMAGE_SCN_ALIGN_256BYTES 0x00900000
#define IMAGE_SCN_ALIGN_512BYTES 0x00A00000
#define IMAGE_SCN_ALIGN_1024BYTES 0x00B00000
#define IMAGE_SCN_ALIGN_2048BYTES 0x00C00000
#define IMAGE_SCN_ALIGN_4096BYTES 0x00D00000
#define IMAGE_SCN_ALIGN_8192BYTES 0x00E00000

#define IMAGE_SCN_ALIGN_MASK 0x00F00000

#define IMAGE_SCN_LNK_NRELOC_OVFL 0x01000000
#define IMAGE_SCN_MEM_DISCARDABLE 0x02000000
#define IMAGE_SCN_MEM_NOT_CACHED 0x04000000
#define IMAGE_SCN_MEM_NOT_PAGED 0x08000000
#define IMAGE_SCN_MEM_SHARED 0x10000000
#define IMAGE_SCN_MEM_EXECUTE 0x20000000
#define IMAGE_SCN_MEM_READ 0x40000000
#define IMAGE_SCN_MEM_WRITE 0x80000000

#define IMAGE_SCN_SCALE_INDEX 0x00000001

#include "pshpack2.h"
    typedef struct _IMAGE_SYMBOL {
      union {
	BYTE ShortName[8];
	struct {
	  DWORD Short;
	  DWORD Long;
	} Name;
	DWORD LongName[2];
      } N;
      DWORD Value;
      SHORT SectionNumber;
      WORD Type;
      BYTE StorageClass;
      BYTE NumberOfAuxSymbols;
    } IMAGE_SYMBOL;
    typedef IMAGE_SYMBOL UNALIGNED *PIMAGE_SYMBOL;

#define IMAGE_SIZEOF_SYMBOL 18

    typedef struct _IMAGE_SYMBOL_EX {
      union {
	BYTE ShortName[8];
	struct {
	  DWORD Short;
	  DWORD Long;
	} Name;
	DWORD LongName[2];
      } N;
      DWORD Value;
      LONG SectionNumber;
      WORD Type;
      BYTE StorageClass;
      BYTE NumberOfAuxSymbols;
    } IMAGE_SYMBOL_EX,UNALIGNED *PIMAGE_SYMBOL_EX;

#define IMAGE_SYM_UNDEFINED (SHORT)0
#define IMAGE_SYM_ABSOLUTE (SHORT)-1
#define IMAGE_SYM_DEBUG (SHORT)-2
#define IMAGE_SYM_SECTION_MAX 0xFEFF
#define IMAGE_SYM_SECTION_MAX_EX MAXLONG

#define IMAGE_SYM_TYPE_NULL 0x0000
#define IMAGE_SYM_TYPE_VOID 0x0001
#define IMAGE_SYM_TYPE_CHAR 0x0002
#define IMAGE_SYM_TYPE_SHORT 0x0003
#define IMAGE_SYM_TYPE_INT 0x0004
#define IMAGE_SYM_TYPE_LONG 0x0005
#define IMAGE_SYM_TYPE_FLOAT 0x0006
#define IMAGE_SYM_TYPE_DOUBLE 0x0007
#define IMAGE_SYM_TYPE_STRUCT 0x0008
#define IMAGE_SYM_TYPE_UNION 0x0009
#define IMAGE_SYM_TYPE_ENUM 0x000A
#define IMAGE_SYM_TYPE_MOE 0x000B
#define IMAGE_SYM_TYPE_BYTE 0x000C
#define IMAGE_SYM_TYPE_WORD 0x000D
#define IMAGE_SYM_TYPE_UINT 0x000E
#define IMAGE_SYM_TYPE_DWORD 0x000F
#define IMAGE_SYM_TYPE_PCODE 0x8000

#define IMAGE_SYM_DTYPE_NULL 0
#define IMAGE_SYM_DTYPE_POINTER 1
#define IMAGE_SYM_DTYPE_FUNCTION 2
#define IMAGE_SYM_DTYPE_ARRAY 3

#define IMAGE_SYM_CLASS_END_OF_FUNCTION (BYTE)-1
#define IMAGE_SYM_CLASS_NULL 0x0000
#define IMAGE_SYM_CLASS_AUTOMATIC 0x0001
#define IMAGE_SYM_CLASS_EXTERNAL 0x0002
#define IMAGE_SYM_CLASS_STATIC 0x0003
#define IMAGE_SYM_CLASS_REGISTER 0x0004
#define IMAGE_SYM_CLASS_EXTERNAL_DEF 0x0005
#define IMAGE_SYM_CLASS_LABEL 0x0006
#define IMAGE_SYM_CLASS_UNDEFINED_LABEL 0x0007
#define IMAGE_SYM_CLASS_MEMBER_OF_STRUCT 0x0008
#define IMAGE_SYM_CLASS_ARGUMENT 0x0009
#define IMAGE_SYM_CLASS_STRUCT_TAG 0x000A
#define IMAGE_SYM_CLASS_MEMBER_OF_UNION 0x000B
#define IMAGE_SYM_CLASS_UNION_TAG 0x000C
#define IMAGE_SYM_CLASS_TYPE_DEFINITION 0x000D
#define IMAGE_SYM_CLASS_UNDEFINED_STATIC 0x000E
#define IMAGE_SYM_CLASS_ENUM_TAG 0x000F
#define IMAGE_SYM_CLASS_MEMBER_OF_ENUM 0x0010
#define IMAGE_SYM_CLASS_REGISTER_PARAM 0x0011
#define IMAGE_SYM_CLASS_BIT_FIELD 0x0012
#define IMAGE_SYM_CLASS_FAR_EXTERNAL 0x0044
#define IMAGE_SYM_CLASS_BLOCK 0x0064
#define IMAGE_SYM_CLASS_FUNCTION 0x0065
#define IMAGE_SYM_CLASS_END_OF_STRUCT 0x0066
#define IMAGE_SYM_CLASS_FILE 0x0067
#define IMAGE_SYM_CLASS_SECTION 0x0068
#define IMAGE_SYM_CLASS_WEAK_EXTERNAL 0x0069
#define IMAGE_SYM_CLASS_CLR_TOKEN 0x006B

#define N_BTMASK 0x000F
#define N_TMASK 0x0030
#define N_TMASK1 0x00C0
#define N_TMASK2 0x00F0
#define N_BTSHFT 4
#define N_TSHIFT 2

#define BTYPE(x) ((x) & N_BTMASK)

#ifndef ISPTR
#define ISPTR(x) (((x) & N_TMASK)==(IMAGE_SYM_DTYPE_POINTER << N_BTSHFT))
#endif

#ifndef ISFCN
#define ISFCN(x) (((x) & N_TMASK)==(IMAGE_SYM_DTYPE_FUNCTION << N_BTSHFT))
#endif

#ifndef ISARY
#define ISARY(x) (((x) & N_TMASK)==(IMAGE_SYM_DTYPE_ARRAY << N_BTSHFT))
#endif

#ifndef ISTAG
#define ISTAG(x) ((x)==IMAGE_SYM_CLASS_STRUCT_TAG || (x)==IMAGE_SYM_CLASS_UNION_TAG || (x)==IMAGE_SYM_CLASS_ENUM_TAG)
#endif

#ifndef INCREF
#define INCREF(x) ((((x)&~N_BTMASK)<<N_TSHIFT)|(IMAGE_SYM_DTYPE_POINTER<<N_BTSHFT)|((x)&N_BTMASK))
#endif
#ifndef DECREF
#define DECREF(x) ((((x)>>N_TSHIFT)&~N_BTMASK)|((x)&N_BTMASK))
#endif

#include <pshpack2.h>
    typedef struct IMAGE_AUX_SYMBOL_TOKEN_DEF {
      BYTE bAuxType;
      BYTE bReserved;
      DWORD SymbolTableIndex;
      BYTE rgbReserved[12];
    } IMAGE_AUX_SYMBOL_TOKEN_DEF,UNALIGNED *PIMAGE_AUX_SYMBOL_TOKEN_DEF;
#include <poppack.h>

    typedef union _IMAGE_AUX_SYMBOL {
      struct {
	DWORD TagIndex;
	union {
	  struct {
	    WORD Linenumber;
	    WORD Size;
	  } LnSz;
	  DWORD TotalSize;
	} Misc;
	union {
	  struct {
	    DWORD PointerToLinenumber;
	    DWORD PointerToNextFunction;
	  } Function;
	  struct {
	    WORD Dimension[4];
	  } Array;
	} FcnAry;
	WORD TvIndex;
      } Sym;
      struct {
	BYTE Name[IMAGE_SIZEOF_SYMBOL];
      } File;
      struct {
	DWORD Length;
	WORD NumberOfRelocations;
	WORD NumberOfLinenumbers;
	DWORD CheckSum;
	SHORT Number;
	BYTE Selection;
      } Section;
      IMAGE_AUX_SYMBOL_TOKEN_DEF TokenDef;
      struct {
	DWORD crc;
	BYTE rgbReserved[14];
      } CRC;
    } IMAGE_AUX_SYMBOL,UNALIGNED *PIMAGE_AUX_SYMBOL;

    typedef union _IMAGE_AUX_SYMBOL_EX {
      struct {
	DWORD WeakDefaultSymIndex;
	DWORD WeakSearchType;
	BYTE rgbReserved[12];
      } Sym;
      struct {
	BYTE Name[sizeof (IMAGE_SYMBOL_EX)];
      } File;
      struct {
	DWORD Length;
	WORD NumberOfRelocations;
	WORD NumberOfLinenumbers;
	DWORD CheckSum;
	SHORT Number;
	BYTE Selection;
	BYTE bReserved;
	SHORT HighNumber;
	BYTE rgbReserved[2];
      } Section;
      __C89_NAMELESS struct {
	IMAGE_AUX_SYMBOL_TOKEN_DEF TokenDef;
	BYTE rgbReserved[2];
      };
      struct {
	DWORD crc;
	BYTE rgbReserved[16];
      } CRC;
    } IMAGE_AUX_SYMBOL_EX,UNALIGNED *PIMAGE_AUX_SYMBOL_EX;

#define IMAGE_SIZEOF_AUX_SYMBOL 18

    typedef enum IMAGE_AUX_SYMBOL_TYPE {
      IMAGE_AUX_SYMBOL_TYPE_TOKEN_DEF = 1
    } IMAGE_AUX_SYMBOL_TYPE;

#define IMAGE_COMDAT_SELECT_NODUPLICATES 1
#define IMAGE_COMDAT_SELECT_ANY 2
#define IMAGE_COMDAT_SELECT_SAME_SIZE 3
#define IMAGE_COMDAT_SELECT_EXACT_MATCH 4
#define IMAGE_COMDAT_SELECT_ASSOCIATIVE 5
#define IMAGE_COMDAT_SELECT_LARGEST 6
#define IMAGE_COMDAT_SELECT_NEWEST 7

#define IMAGE_WEAK_EXTERN_SEARCH_NOLIBRARY 1
#define IMAGE_WEAK_EXTERN_SEARCH_LIBRARY 2
#define IMAGE_WEAK_EXTERN_SEARCH_ALIAS 3

    typedef struct _IMAGE_RELOCATION {
      __C89_NAMELESS union {
	DWORD VirtualAddress;
	DWORD RelocCount;
      } DUMMYUNIONNAME;
      DWORD SymbolTableIndex;
      WORD Type;
    } IMAGE_RELOCATION;
    typedef IMAGE_RELOCATION UNALIGNED *PIMAGE_RELOCATION;

#define IMAGE_SIZEOF_RELOCATION 10

#define IMAGE_REL_I386_ABSOLUTE 0x0000
#define IMAGE_REL_I386_DIR16 0x0001
#define IMAGE_REL_I386_REL16 0x0002
#define IMAGE_REL_I386_DIR32 0x0006
#define IMAGE_REL_I386_DIR32NB 0x0007
#define IMAGE_REL_I386_SEG12 0x0009
#define IMAGE_REL_I386_SECTION 0x000A
#define IMAGE_REL_I386_SECREL 0x000B
#define IMAGE_REL_I386_TOKEN 0x000C
#define IMAGE_REL_I386_SECREL7 0x000D
#define IMAGE_REL_I386_REL32 0x0014

#define IMAGE_REL_MIPS_ABSOLUTE 0x0000
#define IMAGE_REL_MIPS_REFHALF 0x0001
#define IMAGE_REL_MIPS_REFWORD 0x0002
#define IMAGE_REL_MIPS_JMPADDR 0x0003
#define IMAGE_REL_MIPS_REFHI 0x0004
#define IMAGE_REL_MIPS_REFLO 0x0005
#define IMAGE_REL_MIPS_GPREL 0x0006
#define IMAGE_REL_MIPS_LITERAL 0x0007
#define IMAGE_REL_MIPS_SECTION 0x000A
#define IMAGE_REL_MIPS_SECREL 0x000B
#define IMAGE_REL_MIPS_SECRELLO 0x000C
#define IMAGE_REL_MIPS_SECRELHI 0x000D
#define IMAGE_REL_MIPS_TOKEN 0x000E
#define IMAGE_REL_MIPS_JMPADDR16 0x0010
#define IMAGE_REL_MIPS_REFWORDNB 0x0022
#define IMAGE_REL_MIPS_PAIR 0x0025

#define IMAGE_REL_ALPHA_ABSOLUTE 0x0000
#define IMAGE_REL_ALPHA_REFLONG 0x0001
#define IMAGE_REL_ALPHA_REFQUAD 0x0002
#define IMAGE_REL_ALPHA_GPREL32 0x0003
#define IMAGE_REL_ALPHA_LITERAL 0x0004
#define IMAGE_REL_ALPHA_LITUSE 0x0005
#define IMAGE_REL_ALPHA_GPDISP 0x0006
#define IMAGE_REL_ALPHA_BRADDR 0x0007
#define IMAGE_REL_ALPHA_HINT 0x0008
#define IMAGE_REL_ALPHA_INLINE_REFLONG 0x0009
#define IMAGE_REL_ALPHA_REFHI 0x000A
#define IMAGE_REL_ALPHA_REFLO 0x000B
#define IMAGE_REL_ALPHA_PAIR 0x000C
#define IMAGE_REL_ALPHA_MATCH 0x000D
#define IMAGE_REL_ALPHA_SECTION 0x000E
#define IMAGE_REL_ALPHA_SECREL 0x000F
#define IMAGE_REL_ALPHA_REFLONGNB 0x0010
#define IMAGE_REL_ALPHA_SECRELLO 0x0011
#define IMAGE_REL_ALPHA_SECRELHI 0x0012
#define IMAGE_REL_ALPHA_REFQ3 0x0013
#define IMAGE_REL_ALPHA_REFQ2 0x0014
#define IMAGE_REL_ALPHA_REFQ1 0x0015
#define IMAGE_REL_ALPHA_GPRELLO 0x0016
#define IMAGE_REL_ALPHA_GPRELHI 0x0017

#define IMAGE_REL_PPC_ABSOLUTE 0x0000
#define IMAGE_REL_PPC_ADDR64 0x0001
#define IMAGE_REL_PPC_ADDR32 0x0002
#define IMAGE_REL_PPC_ADDR24 0x0003
#define IMAGE_REL_PPC_ADDR16 0x0004
#define IMAGE_REL_PPC_ADDR14 0x0005
#define IMAGE_REL_PPC_REL24 0x0006
#define IMAGE_REL_PPC_REL14 0x0007
#define IMAGE_REL_PPC_TOCREL16 0x0008
#define IMAGE_REL_PPC_TOCREL14 0x0009
#define IMAGE_REL_PPC_ADDR32NB 0x000A
#define IMAGE_REL_PPC_SECREL 0x000B
#define IMAGE_REL_PPC_SECTION 0x000C
#define IMAGE_REL_PPC_IFGLUE 0x000D
#define IMAGE_REL_PPC_IMGLUE 0x000E
#define IMAGE_REL_PPC_SECREL16 0x000F
#define IMAGE_REL_PPC_REFHI 0x0010
#define IMAGE_REL_PPC_REFLO 0x0011
#define IMAGE_REL_PPC_PAIR 0x0012
#define IMAGE_REL_PPC_SECRELLO 0x0013
#define IMAGE_REL_PPC_SECRELHI 0x0014
#define IMAGE_REL_PPC_GPREL 0x0015
#define IMAGE_REL_PPC_TOKEN 0x0016
#define IMAGE_REL_PPC_TYPEMASK 0x00FF
#define IMAGE_REL_PPC_NEG 0x0100
#define IMAGE_REL_PPC_BRTAKEN 0x0200
#define IMAGE_REL_PPC_BRNTAKEN 0x0400
#define IMAGE_REL_PPC_TOCDEFN 0x0800

#define IMAGE_REL_SH3_ABSOLUTE 0x0000
#define IMAGE_REL_SH3_DIRECT16 0x0001
#define IMAGE_REL_SH3_DIRECT32 0x0002
#define IMAGE_REL_SH3_DIRECT8 0x0003
#define IMAGE_REL_SH3_DIRECT8_WORD 0x0004
#define IMAGE_REL_SH3_DIRECT8_LONG 0x0005
#define IMAGE_REL_SH3_DIRECT4 0x0006
#define IMAGE_REL_SH3_DIRECT4_WORD 0x0007
#define IMAGE_REL_SH3_DIRECT4_LONG 0x0008
#define IMAGE_REL_SH3_PCREL8_WORD 0x0009
#define IMAGE_REL_SH3_PCREL8_LONG 0x000A
#define IMAGE_REL_SH3_PCREL12_WORD 0x000B
#define IMAGE_REL_SH3_STARTOF_SECTION 0x000C
#define IMAGE_REL_SH3_SIZEOF_SECTION 0x000D
#define IMAGE_REL_SH3_SECTION 0x000E
#define IMAGE_REL_SH3_SECREL 0x000F
#define IMAGE_REL_SH3_DIRECT32_NB 0x0010
#define IMAGE_REL_SH3_GPREL4_LONG 0x0011
#define IMAGE_REL_SH3_TOKEN 0x0012

#define IMAGE_REL_SHM_PCRELPT 0x0013
#define IMAGE_REL_SHM_REFLO 0x0014
#define IMAGE_REL_SHM_REFHALF 0x0015
#define IMAGE_REL_SHM_RELLO 0x0016
#define IMAGE_REL_SHM_RELHALF 0x0017
#define IMAGE_REL_SHM_PAIR 0x0018

#define IMAGE_REL_SH_NOMODE 0x8000

#define IMAGE_REL_ARM_ABSOLUTE 0x0000
#define IMAGE_REL_ARM_ADDR32 0x0001
#define IMAGE_REL_ARM_ADDR32NB 0x0002
#define IMAGE_REL_ARM_BRANCH24 0x0003
#define IMAGE_REL_ARM_BRANCH11 0x0004
#define IMAGE_REL_ARM_TOKEN 0x0005
#define IMAGE_REL_ARM_GPREL12 0x0006
#define IMAGE_REL_ARM_GPREL7 0x0007
#define IMAGE_REL_ARM_BLX24 0x0008
#define IMAGE_REL_ARM_BLX11 0x0009
#define IMAGE_REL_ARM_SECTION 0x000E
#define IMAGE_REL_ARM_SECREL 0x000F
#define IMAGE_REL_ARM_MOV32A 0x0010
#define IMAGE_REL_ARM_MOV32 0x0010
#define IMAGE_REL_ARM_MOV32T 0x0011
#define IMAGE_REL_THUMB_MOV32 0x0011
#define IMAGE_REL_ARM_BRANCH20T 0x0012
#define IMAGE_REL_THUMB_BRANCH20 0x0012
#define IMAGE_REL_ARM_BRANCH24T 0x0014
#define IMAGE_REL_THUMB_BRANCH24 0x0014
#define IMAGE_REL_ARM_BLX23T 0x0015
#define IMAGE_REL_THUMB_BLX23 0x0015

#define IMAGE_REL_AM_ABSOLUTE 0x0000
#define IMAGE_REL_AM_ADDR32 0x0001
#define IMAGE_REL_AM_ADDR32NB 0x0002
#define IMAGE_REL_AM_CALL32 0x0003
#define IMAGE_REL_AM_FUNCINFO 0x0004
#define IMAGE_REL_AM_REL32_1 0x0005
#define IMAGE_REL_AM_REL32_2 0x0006
#define IMAGE_REL_AM_SECREL 0x0007
#define IMAGE_REL_AM_SECTION 0x0008
#define IMAGE_REL_AM_TOKEN 0x0009

#define IMAGE_REL_AMD64_ABSOLUTE 0x0000
#define IMAGE_REL_AMD64_ADDR64 0x0001
#define IMAGE_REL_AMD64_ADDR32 0x0002
#define IMAGE_REL_AMD64_ADDR32NB 0x0003
#define IMAGE_REL_AMD64_REL32 0x0004
#define IMAGE_REL_AMD64_REL32_1 0x0005
#define IMAGE_REL_AMD64_REL32_2 0x0006
#define IMAGE_REL_AMD64_REL32_3 0x0007
#define IMAGE_REL_AMD64_REL32_4 0x0008
#define IMAGE_REL_AMD64_REL32_5 0x0009
#define IMAGE_REL_AMD64_SECTION 0x000A
#define IMAGE_REL_AMD64_SECREL 0x000B
#define IMAGE_REL_AMD64_SECREL7 0x000C
#define IMAGE_REL_AMD64_TOKEN 0x000D
#define IMAGE_REL_AMD64_SREL32 0x000E
#define IMAGE_REL_AMD64_PAIR 0x000F
#define IMAGE_REL_AMD64_SSPAN32 0x0010

#define IMAGE_REL_IA64_ABSOLUTE 0x0000
#define IMAGE_REL_IA64_IMM14 0x0001
#define IMAGE_REL_IA64_IMM22 0x0002
#define IMAGE_REL_IA64_IMM64 0x0003
#define IMAGE_REL_IA64_DIR32 0x0004
#define IMAGE_REL_IA64_DIR64 0x0005
#define IMAGE_REL_IA64_PCREL21B 0x0006
#define IMAGE_REL_IA64_PCREL21M 0x0007
#define IMAGE_REL_IA64_PCREL21F 0x0008
#define IMAGE_REL_IA64_GPREL22 0x0009
#define IMAGE_REL_IA64_LTOFF22 0x000A
#define IMAGE_REL_IA64_SECTION 0x000B
#define IMAGE_REL_IA64_SECREL22 0x000C
#define IMAGE_REL_IA64_SECREL64I 0x000D
#define IMAGE_REL_IA64_SECREL32 0x000E

#define IMAGE_REL_IA64_DIR32NB 0x0010
#define IMAGE_REL_IA64_SREL14 0x0011
#define IMAGE_REL_IA64_SREL22 0x0012
#define IMAGE_REL_IA64_SREL32 0x0013
#define IMAGE_REL_IA64_UREL32 0x0014
#define IMAGE_REL_IA64_PCREL60X 0x0015
#define IMAGE_REL_IA64_PCREL60B 0x0016
#define IMAGE_REL_IA64_PCREL60F 0x0017
#define IMAGE_REL_IA64_PCREL60I 0x0018
#define IMAGE_REL_IA64_PCREL60M 0x0019
#define IMAGE_REL_IA64_IMMGPREL64 0x001A
#define IMAGE_REL_IA64_TOKEN 0x001B
#define IMAGE_REL_IA64_GPREL32 0x001C
#define IMAGE_REL_IA64_ADDEND 0x001F

#define IMAGE_REL_CEF_ABSOLUTE 0x0000
#define IMAGE_REL_CEF_ADDR32 0x0001
#define IMAGE_REL_CEF_ADDR64 0x0002
#define IMAGE_REL_CEF_ADDR32NB 0x0003
#define IMAGE_REL_CEF_SECTION 0x0004
#define IMAGE_REL_CEF_SECREL 0x0005
#define IMAGE_REL_CEF_TOKEN 0x0006

#define IMAGE_REL_CEE_ABSOLUTE 0x0000
#define IMAGE_REL_CEE_ADDR32 0x0001
#define IMAGE_REL_CEE_ADDR64 0x0002
#define IMAGE_REL_CEE_ADDR32NB 0x0003
#define IMAGE_REL_CEE_SECTION 0x0004
#define IMAGE_REL_CEE_SECREL 0x0005
#define IMAGE_REL_CEE_TOKEN 0x0006

#define IMAGE_REL_M32R_ABSOLUTE 0x0000
#define IMAGE_REL_M32R_ADDR32 0x0001
#define IMAGE_REL_M32R_ADDR32NB 0x0002
#define IMAGE_REL_M32R_ADDR24 0x0003
#define IMAGE_REL_M32R_GPREL16 0x0004
#define IMAGE_REL_M32R_PCREL24 0x0005
#define IMAGE_REL_M32R_PCREL16 0x0006
#define IMAGE_REL_M32R_PCREL8 0x0007
#define IMAGE_REL_M32R_REFHALF 0x0008
#define IMAGE_REL_M32R_REFHI 0x0009
#define IMAGE_REL_M32R_REFLO 0x000A
#define IMAGE_REL_M32R_PAIR 0x000B
#define IMAGE_REL_M32R_SECTION 0x000C
#define IMAGE_REL_M32R_SECREL32 0x000D
#define IMAGE_REL_M32R_TOKEN 0x000E

#define IMAGE_REL_EBC_ABSOLUTE 0x0000
#define IMAGE_REL_EBC_ADDR32NB 0x0001
#define IMAGE_REL_EBC_REL32 0x0002
#define IMAGE_REL_EBC_SECTION 0x0003
#define IMAGE_REL_EBC_SECREL 0x0004

#define EXT_IMM64(Value,Address,Size,InstPos,ValPos) Value |= (((ULONGLONG)((*(Address) >> InstPos) & (((ULONGLONG)1 << Size) - 1))) << ValPos)
#define INS_IMM64(Value,Address,Size,InstPos,ValPos) *(PDWORD)Address = (*(PDWORD)Address & ~(((1 << Size) - 1) << InstPos)) | ((DWORD)((((ULONGLONG)Value >> ValPos) & (((ULONGLONG)1 << Size) - 1))) << InstPos)

#define EMARCH_ENC_I17_IMM7B_INST_WORD_X 3
#define EMARCH_ENC_I17_IMM7B_SIZE_X 7
#define EMARCH_ENC_I17_IMM7B_INST_WORD_POS_X 4
#define EMARCH_ENC_I17_IMM7B_VAL_POS_X 0

#define EMARCH_ENC_I17_IMM9D_INST_WORD_X 3
#define EMARCH_ENC_I17_IMM9D_SIZE_X 9
#define EMARCH_ENC_I17_IMM9D_INST_WORD_POS_X 18
#define EMARCH_ENC_I17_IMM9D_VAL_POS_X 7

#define EMARCH_ENC_I17_IMM5C_INST_WORD_X 3
#define EMARCH_ENC_I17_IMM5C_SIZE_X 5
#define EMARCH_ENC_I17_IMM5C_INST_WORD_POS_X 13
#define EMARCH_ENC_I17_IMM5C_VAL_POS_X 16

#define EMARCH_ENC_I17_IC_INST_WORD_X 3
#define EMARCH_ENC_I17_IC_SIZE_X 1
#define EMARCH_ENC_I17_IC_INST_WORD_POS_X 12
#define EMARCH_ENC_I17_IC_VAL_POS_X 21

#define EMARCH_ENC_I17_IMM41a_INST_WORD_X 1
#define EMARCH_ENC_I17_IMM41a_SIZE_X 10
#define EMARCH_ENC_I17_IMM41a_INST_WORD_POS_X 14
#define EMARCH_ENC_I17_IMM41a_VAL_POS_X 22

#define EMARCH_ENC_I17_IMM41b_INST_WORD_X 1
#define EMARCH_ENC_I17_IMM41b_SIZE_X 8
#define EMARCH_ENC_I17_IMM41b_INST_WORD_POS_X 24
#define EMARCH_ENC_I17_IMM41b_VAL_POS_X 32

#define EMARCH_ENC_I17_IMM41c_INST_WORD_X 2
#define EMARCH_ENC_I17_IMM41c_SIZE_X 23
#define EMARCH_ENC_I17_IMM41c_INST_WORD_POS_X 0
#define EMARCH_ENC_I17_IMM41c_VAL_POS_X 40

#define EMARCH_ENC_I17_SIGN_INST_WORD_X 3
#define EMARCH_ENC_I17_SIGN_SIZE_X 1
#define EMARCH_ENC_I17_SIGN_INST_WORD_POS_X 27
#define EMARCH_ENC_I17_SIGN_VAL_POS_X 63

#define X3_OPCODE_INST_WORD_X 3
#define X3_OPCODE_SIZE_X 4
#define X3_OPCODE_INST_WORD_POS_X 28
#define X3_OPCODE_SIGN_VAL_POS_X 0

#define X3_I_INST_WORD_X 3
#define X3_I_SIZE_X 1
#define X3_I_INST_WORD_POS_X 27
#define X3_I_SIGN_VAL_POS_X 59

#define X3_D_WH_INST_WORD_X 3
#define X3_D_WH_SIZE_X 3
#define X3_D_WH_INST_WORD_POS_X 24
#define X3_D_WH_SIGN_VAL_POS_X 0

#define X3_IMM20_INST_WORD_X 3
#define X3_IMM20_SIZE_X 20
#define X3_IMM20_INST_WORD_POS_X 4
#define X3_IMM20_SIGN_VAL_POS_X 0

#define X3_IMM39_1_INST_WORD_X 2
#define X3_IMM39_1_SIZE_X 23
#define X3_IMM39_1_INST_WORD_POS_X 0
#define X3_IMM39_1_SIGN_VAL_POS_X 36

#define X3_IMM39_2_INST_WORD_X 1
#define X3_IMM39_2_SIZE_X 16
#define X3_IMM39_2_INST_WORD_POS_X 16
#define X3_IMM39_2_SIGN_VAL_POS_X 20

#define X3_P_INST_WORD_X 3
#define X3_P_SIZE_X 4
#define X3_P_INST_WORD_POS_X 0
#define X3_P_SIGN_VAL_POS_X 0

#define X3_TMPLT_INST_WORD_X 0
#define X3_TMPLT_SIZE_X 4
#define X3_TMPLT_INST_WORD_POS_X 0
#define X3_TMPLT_SIGN_VAL_POS_X 0

#define X3_BTYPE_QP_INST_WORD_X 2
#define X3_BTYPE_QP_SIZE_X 9
#define X3_BTYPE_QP_INST_WORD_POS_X 23
#define X3_BTYPE_QP_INST_VAL_POS_X 0

#define X3_EMPTY_INST_WORD_X 1
#define X3_EMPTY_SIZE_X 2
#define X3_EMPTY_INST_WORD_POS_X 14
#define X3_EMPTY_INST_VAL_POS_X 0

    typedef struct _IMAGE_LINENUMBER {
      union {
	DWORD SymbolTableIndex;
	DWORD VirtualAddress;
      } Type;
      WORD Linenumber;
    } IMAGE_LINENUMBER;
    typedef IMAGE_LINENUMBER UNALIGNED *PIMAGE_LINENUMBER;

#define IMAGE_SIZEOF_LINENUMBER 6

#include "poppack.h"

    typedef struct _IMAGE_BASE_RELOCATION {
      DWORD VirtualAddress;
      DWORD SizeOfBlock;
    } IMAGE_BASE_RELOCATION;
    typedef IMAGE_BASE_RELOCATION UNALIGNED *PIMAGE_BASE_RELOCATION;

#define IMAGE_SIZEOF_BASE_RELOCATION 8

#define IMAGE_REL_BASED_ABSOLUTE 0
#define IMAGE_REL_BASED_HIGH 1
#define IMAGE_REL_BASED_LOW 2
#define IMAGE_REL_BASED_HIGHLOW 3
#define IMAGE_REL_BASED_HIGHADJ 4
#define IMAGE_REL_BASED_MIPS_JMPADDR 5
#define IMAGE_REL_BASED_ARM_MOV32 5
#define IMAGE_REL_BASED_THUMB_MOV32 7
#define IMAGE_REL_BASED_MIPS_JMPADDR16 9
#define IMAGE_REL_BASED_IA64_IMM64 9
#define IMAGE_REL_BASED_DIR64 10

#define IMAGE_ARCHIVE_START_SIZE 8
#define IMAGE_ARCHIVE_START "!<arch>\n"
#define IMAGE_ARCHIVE_END "`\n"
#define IMAGE_ARCHIVE_PAD "\n"
#define IMAGE_ARCHIVE_LINKER_MEMBER "/               "
#define IMAGE_ARCHIVE_LONGNAMES_MEMBER "//              "

    typedef struct _IMAGE_ARCHIVE_MEMBER_HEADER {
      BYTE Name[16];
      BYTE Date[12];
      BYTE UserID[6];
      BYTE GroupID[6];
      BYTE Mode[8];
      BYTE Size[10];
      BYTE EndHeader[2];
    } IMAGE_ARCHIVE_MEMBER_HEADER,*PIMAGE_ARCHIVE_MEMBER_HEADER;

#define IMAGE_SIZEOF_ARCHIVE_MEMBER_HDR 60

    typedef struct _IMAGE_EXPORT_DIRECTORY {
      DWORD Characteristics;
      DWORD TimeDateStamp;
      WORD MajorVersion;
      WORD MinorVersion;
      DWORD Name;
      DWORD Base;
      DWORD NumberOfFunctions;
      DWORD NumberOfNames;
      DWORD AddressOfFunctions;
      DWORD AddressOfNames;
      DWORD AddressOfNameOrdinals;
    } IMAGE_EXPORT_DIRECTORY,*PIMAGE_EXPORT_DIRECTORY;

    typedef struct _IMAGE_IMPORT_BY_NAME {
      WORD Hint;
      CHAR Name[1];
    } IMAGE_IMPORT_BY_NAME,*PIMAGE_IMPORT_BY_NAME;

#include "pshpack8.h"

    typedef struct _IMAGE_THUNK_DATA64 {
      union {
	ULONGLONG ForwarderString;
	ULONGLONG Function;
	ULONGLONG Ordinal;
	ULONGLONG AddressOfData;
      } u1;
    } IMAGE_THUNK_DATA64;
    typedef IMAGE_THUNK_DATA64 *PIMAGE_THUNK_DATA64;

#include "poppack.h"

    typedef struct _IMAGE_THUNK_DATA32 {
      union {
	DWORD ForwarderString;
	DWORD Function;
	DWORD Ordinal;
	DWORD AddressOfData;
      } u1;
    } IMAGE_THUNK_DATA32;
    typedef IMAGE_THUNK_DATA32 *PIMAGE_THUNK_DATA32;

#define IMAGE_ORDINAL_FLAG64 0x8000000000000000ull
#define IMAGE_ORDINAL_FLAG32 0x80000000
#define IMAGE_ORDINAL64(Ordinal) (Ordinal & 0xffffull)
#define IMAGE_ORDINAL32(Ordinal) (Ordinal & 0xffff)
#define IMAGE_SNAP_BY_ORDINAL64(Ordinal) ((Ordinal & IMAGE_ORDINAL_FLAG64)!=0)
#define IMAGE_SNAP_BY_ORDINAL32(Ordinal) ((Ordinal & IMAGE_ORDINAL_FLAG32)!=0)

    typedef VOID (NTAPI *PIMAGE_TLS_CALLBACK)(PVOID DllHandle,DWORD Reason,PVOID Reserved);

    typedef struct _IMAGE_TLS_DIRECTORY64 {
      ULONGLONG StartAddressOfRawData;
      ULONGLONG EndAddressOfRawData;
      ULONGLONG AddressOfIndex;
      ULONGLONG AddressOfCallBacks;
      DWORD SizeOfZeroFill;
      DWORD Characteristics;
    } IMAGE_TLS_DIRECTORY64;
    typedef IMAGE_TLS_DIRECTORY64 *PIMAGE_TLS_DIRECTORY64;

    typedef struct _IMAGE_TLS_DIRECTORY32 {
      DWORD StartAddressOfRawData;
      DWORD EndAddressOfRawData;
      DWORD AddressOfIndex;
      DWORD AddressOfCallBacks;
      DWORD SizeOfZeroFill;
      DWORD Characteristics;
    } IMAGE_TLS_DIRECTORY32;
    typedef IMAGE_TLS_DIRECTORY32 *PIMAGE_TLS_DIRECTORY32;

#ifdef _WIN64
#define IMAGE_ORDINAL_FLAG IMAGE_ORDINAL_FLAG64
#define IMAGE_ORDINAL(Ordinal) IMAGE_ORDINAL64(Ordinal)
    typedef IMAGE_THUNK_DATA64 IMAGE_THUNK_DATA;
    typedef PIMAGE_THUNK_DATA64 PIMAGE_THUNK_DATA;
#define IMAGE_SNAP_BY_ORDINAL(Ordinal) IMAGE_SNAP_BY_ORDINAL64(Ordinal)
    typedef IMAGE_TLS_DIRECTORY64 IMAGE_TLS_DIRECTORY;
    typedef PIMAGE_TLS_DIRECTORY64 PIMAGE_TLS_DIRECTORY;
#else  /* _WIN64 */
#define IMAGE_ORDINAL_FLAG IMAGE_ORDINAL_FLAG32
#define IMAGE_ORDINAL(Ordinal) IMAGE_ORDINAL32(Ordinal)
    typedef IMAGE_THUNK_DATA32 IMAGE_THUNK_DATA;
    typedef PIMAGE_THUNK_DATA32 PIMAGE_THUNK_DATA;
#define IMAGE_SNAP_BY_ORDINAL(Ordinal) IMAGE_SNAP_BY_ORDINAL32(Ordinal)
    typedef IMAGE_TLS_DIRECTORY32 IMAGE_TLS_DIRECTORY;
    typedef PIMAGE_TLS_DIRECTORY32 PIMAGE_TLS_DIRECTORY;
#endif /* _WIN64 */

    typedef struct _IMAGE_IMPORT_DESCRIPTOR {
      __C89_NAMELESS union {
	DWORD Characteristics;
	DWORD OriginalFirstThunk;
      } DUMMYUNIONNAME;
      DWORD TimeDateStamp;

      DWORD ForwarderChain;
      DWORD Name;
      DWORD FirstThunk;
    } IMAGE_IMPORT_DESCRIPTOR;
    typedef IMAGE_IMPORT_DESCRIPTOR UNALIGNED *PIMAGE_IMPORT_DESCRIPTOR;

    typedef struct _IMAGE_BOUND_IMPORT_DESCRIPTOR {
      DWORD TimeDateStamp;
      WORD OffsetModuleName;
      WORD NumberOfModuleForwarderRefs;
    } IMAGE_BOUND_IMPORT_DESCRIPTOR,*PIMAGE_BOUND_IMPORT_DESCRIPTOR;

    typedef struct _IMAGE_BOUND_FORWARDER_REF {
      DWORD TimeDateStamp;
      WORD OffsetModuleName;
      WORD Reserved;
    } IMAGE_BOUND_FORWARDER_REF,*PIMAGE_BOUND_FORWARDER_REF;

    typedef struct _IMAGE_DELAYLOAD_DESCRIPTOR {
      union {
	DWORD AllAttributes;
	__C89_NAMELESS struct {
	  DWORD RvaBased : 1;
	  DWORD ReservedAttributes : 31;
	};
      } Attributes;
      DWORD DllNameRVA;
      DWORD ModuleHandleRVA;
      DWORD ImportAddressTableRVA;
      DWORD ImportNameTableRVA;
      DWORD BoundImportAddressTableRVA;
      DWORD UnloadInformationTableRVA;
      DWORD TimeDateStamp;
    } IMAGE_DELAYLOAD_DESCRIPTOR,*PIMAGE_DELAYLOAD_DESCRIPTOR;
    typedef const IMAGE_DELAYLOAD_DESCRIPTOR *PCIMAGE_DELAYLOAD_DESCRIPTOR;

    typedef struct _IMAGE_RESOURCE_DIRECTORY {
      DWORD Characteristics;
      DWORD TimeDateStamp;
      WORD MajorVersion;
      WORD MinorVersion;
      WORD NumberOfNamedEntries;
      WORD NumberOfIdEntries;
    } IMAGE_RESOURCE_DIRECTORY,*PIMAGE_RESOURCE_DIRECTORY;

#define IMAGE_RESOURCE_NAME_IS_STRING 0x80000000
#define IMAGE_RESOURCE_DATA_IS_DIRECTORY 0x80000000

    typedef struct _IMAGE_RESOURCE_DIRECTORY_ENTRY {
      __C89_NAMELESS union {
	__C89_NAMELESS struct {
	  DWORD NameOffset:31;
	  DWORD NameIsString:1;
	} DUMMYSTRUCTNAME;
	DWORD Name;
	WORD Id;
      } DUMMYUNIONNAME;
      __C89_NAMELESS union {
	DWORD OffsetToData;
	__C89_NAMELESS struct {
	  DWORD OffsetToDirectory:31;
	  DWORD DataIsDirectory:1;
	} DUMMYSTRUCTNAME2;
      } DUMMYUNIONNAME2;
    } IMAGE_RESOURCE_DIRECTORY_ENTRY,*PIMAGE_RESOURCE_DIRECTORY_ENTRY;

    typedef struct _IMAGE_RESOURCE_DIRECTORY_STRING {
      WORD Length;
      CHAR NameString[1];
    } IMAGE_RESOURCE_DIRECTORY_STRING,*PIMAGE_RESOURCE_DIRECTORY_STRING;

    typedef struct _IMAGE_RESOURCE_DIR_STRING_U {
      WORD Length;
      WCHAR NameString[1];
    } IMAGE_RESOURCE_DIR_STRING_U,*PIMAGE_RESOURCE_DIR_STRING_U;

    typedef struct _IMAGE_RESOURCE_DATA_ENTRY {
      DWORD OffsetToData;
      DWORD Size;
      DWORD CodePage;
      DWORD Reserved;
    } IMAGE_RESOURCE_DATA_ENTRY,*PIMAGE_RESOURCE_DATA_ENTRY;

    typedef struct {
      DWORD Size;
      DWORD TimeDateStamp;
      WORD MajorVersion;
      WORD MinorVersion;
      DWORD GlobalFlagsClear;
      DWORD GlobalFlagsSet;
      DWORD CriticalSectionDefaultTimeout;
      DWORD DeCommitFreeBlockThreshold;
      DWORD DeCommitTotalFreeThreshold;
      DWORD LockPrefixTable;
      DWORD MaximumAllocationSize;
      DWORD VirtualMemoryThreshold;
      DWORD ProcessHeapFlags;
      DWORD ProcessAffinityMask;
      WORD CSDVersion;
      WORD Reserved1;
      DWORD EditList;
      DWORD SecurityCookie;
      DWORD SEHandlerTable;
      DWORD SEHandlerCount;
    } IMAGE_LOAD_CONFIG_DIRECTORY32,*PIMAGE_LOAD_CONFIG_DIRECTORY32;

    typedef struct {
      DWORD Size;
      DWORD TimeDateStamp;
      WORD MajorVersion;
      WORD MinorVersion;
      DWORD GlobalFlagsClear;
      DWORD GlobalFlagsSet;
      DWORD CriticalSectionDefaultTimeout;
      ULONGLONG DeCommitFreeBlockThreshold;
      ULONGLONG DeCommitTotalFreeThreshold;
      ULONGLONG LockPrefixTable;
      ULONGLONG MaximumAllocationSize;
      ULONGLONG VirtualMemoryThreshold;
      ULONGLONG ProcessAffinityMask;
      DWORD ProcessHeapFlags;
      WORD CSDVersion;
      WORD Reserved1;
      ULONGLONG EditList;
      ULONGLONG SecurityCookie;
      ULONGLONG SEHandlerTable;
      ULONGLONG SEHandlerCount;
    } IMAGE_LOAD_CONFIG_DIRECTORY64,*PIMAGE_LOAD_CONFIG_DIRECTORY64;

#ifdef _WIN64
    typedef IMAGE_LOAD_CONFIG_DIRECTORY64 IMAGE_LOAD_CONFIG_DIRECTORY;
    typedef PIMAGE_LOAD_CONFIG_DIRECTORY64 PIMAGE_LOAD_CONFIG_DIRECTORY;
#else  /* _WIN64 */
    typedef IMAGE_LOAD_CONFIG_DIRECTORY32 IMAGE_LOAD_CONFIG_DIRECTORY;
    typedef PIMAGE_LOAD_CONFIG_DIRECTORY32 PIMAGE_LOAD_CONFIG_DIRECTORY;
#endif /* _WIN64 */

    typedef struct _IMAGE_CE_RUNTIME_FUNCTION_ENTRY {
      DWORD FuncStart;
      DWORD PrologLen : 8;
      DWORD FuncLen : 22;
      DWORD ThirtyTwoBit : 1;
      DWORD ExceptionFlag : 1;
    } IMAGE_CE_RUNTIME_FUNCTION_ENTRY,*PIMAGE_CE_RUNTIME_FUNCTION_ENTRY;

    typedef struct _IMAGE_ALPHA64_RUNTIME_FUNCTION_ENTRY {
      ULONGLONG BeginAddress;
      ULONGLONG EndAddress;
      ULONGLONG ExceptionHandler;
      ULONGLONG HandlerData;
      ULONGLONG PrologEndAddress;
    } IMAGE_ALPHA64_RUNTIME_FUNCTION_ENTRY,*PIMAGE_ALPHA64_RUNTIME_FUNCTION_ENTRY;

    typedef struct _IMAGE_ALPHA_RUNTIME_FUNCTION_ENTRY {
      DWORD BeginAddress;
      DWORD EndAddress;
      DWORD ExceptionHandler;
      DWORD HandlerData;
      DWORD PrologEndAddress;
    } IMAGE_ALPHA_RUNTIME_FUNCTION_ENTRY,*PIMAGE_ALPHA_RUNTIME_FUNCTION_ENTRY;

    typedef struct _IMAGE_ARM_RUNTIME_FUNCTION_ENTRY {
      DWORD BeginAddress;
      __C89_NAMELESS union {
	DWORD UnwindData;
	__C89_NAMELESS struct {
	  DWORD Flag : 2;
	  DWORD FunctionLength : 11;
	  DWORD Ret : 2;
	  DWORD H : 1;
	  DWORD Reg : 3;
	  DWORD R : 1;
	  DWORD L : 1;
	  DWORD C : 1;
	  DWORD StackAdjust : 10;
	} DUMMYSTRUCTNAME;
      } DUMMYUNIONNAME;
    } IMAGE_ARM_RUNTIME_FUNCTION_ENTRY,*PIMAGE_ARM_RUNTIME_FUNCTION_ENTRY;

    typedef struct _IMAGE_ARM64_RUNTIME_FUNCTION_ENTRY {
      DWORD BeginAddress;
      __C89_NAMELESS union {
	DWORD UnwindData;
	__C89_NAMELESS struct {
	  DWORD Flag : 2;
	  DWORD FunctionLength : 11;
	  DWORD RegF : 3;
	  DWORD RegI : 4;
	  DWORD H : 1;
	  DWORD CR : 2;
	  DWORD FrameSize : 9;
	} DUMMYSTRUCTNAME;
      } DUMMYUNIONNAME;
    } IMAGE_ARM64_RUNTIME_FUNCTION_ENTRY,*PIMAGE_ARM64_RUNTIME_FUNCTION_ENTRY;

    typedef struct _IMAGE_RUNTIME_FUNCTION_ENTRY {
      DWORD BeginAddress;
      DWORD EndAddress;
      __C89_NAMELESS union {
	DWORD UnwindInfoAddress;
	DWORD UnwindData;
      } DUMMYUNIONNAME;
    } _IMAGE_RUNTIME_FUNCTION_ENTRY,*_PIMAGE_RUNTIME_FUNCTION_ENTRY;

    typedef _IMAGE_RUNTIME_FUNCTION_ENTRY IMAGE_IA64_RUNTIME_FUNCTION_ENTRY;
    typedef _PIMAGE_RUNTIME_FUNCTION_ENTRY PIMAGE_IA64_RUNTIME_FUNCTION_ENTRY;

#if defined (_AXP64_)
    typedef IMAGE_ALPHA64_RUNTIME_FUNCTION_ENTRY IMAGE_AXP64_RUNTIME_FUNCTION_ENTRY;
    typedef PIMAGE_ALPHA64_RUNTIME_FUNCTION_ENTRY PIMAGE_AXP64_RUNTIME_FUNCTION_ENTRY;
    typedef IMAGE_ALPHA64_RUNTIME_FUNCTION_ENTRY IMAGE_RUNTIME_FUNCTION_ENTRY;
    typedef PIMAGE_ALPHA64_RUNTIME_FUNCTION_ENTRY PIMAGE_RUNTIME_FUNCTION_ENTRY;
#elif defined (_ALPHA_)
    typedef IMAGE_ALPHA_RUNTIME_FUNCTION_ENTRY IMAGE_RUNTIME_FUNCTION_ENTRY;
    typedef PIMAGE_ALPHA_RUNTIME_FUNCTION_ENTRY PIMAGE_RUNTIME_FUNCTION_ENTRY;
#elif defined (__arm__)
    typedef IMAGE_ARM_RUNTIME_FUNCTION_ENTRY IMAGE_RUNTIME_FUNCTION_ENTRY;
    typedef PIMAGE_ARM_RUNTIME_FUNCTION_ENTRY PIMAGE_RUNTIME_FUNCTION_ENTRY;
#else
    typedef _IMAGE_RUNTIME_FUNCTION_ENTRY IMAGE_RUNTIME_FUNCTION_ENTRY;
    typedef _PIMAGE_RUNTIME_FUNCTION_ENTRY PIMAGE_RUNTIME_FUNCTION_ENTRY;
#endif

    typedef struct _IMAGE_DEBUG_DIRECTORY {
      DWORD Characteristics;
      DWORD TimeDateStamp;
      WORD MajorVersion;
      WORD MinorVersion;
      DWORD Type;
      DWORD SizeOfData;
      DWORD AddressOfRawData;
      DWORD PointerToRawData;
    } IMAGE_DEBUG_DIRECTORY,*PIMAGE_DEBUG_DIRECTORY;

#define IMAGE_DEBUG_TYPE_UNKNOWN 0
#define IMAGE_DEBUG_TYPE_COFF 1
#define IMAGE_DEBUG_TYPE_CODEVIEW 2
#define IMAGE_DEBUG_TYPE_FPO 3
#define IMAGE_DEBUG_TYPE_MISC 4
#define IMAGE_DEBUG_TYPE_EXCEPTION 5
#define IMAGE_DEBUG_TYPE_FIXUP 6
#define IMAGE_DEBUG_TYPE_OMAP_TO_SRC 7
#define IMAGE_DEBUG_TYPE_OMAP_FROM_SRC 8
#define IMAGE_DEBUG_TYPE_BORLAND 9
#define IMAGE_DEBUG_TYPE_RESERVED10 10
#define IMAGE_DEBUG_TYPE_CLSID 11

    typedef struct _IMAGE_COFF_SYMBOLS_HEADER {
      DWORD NumberOfSymbols;
      DWORD LvaToFirstSymbol;
      DWORD NumberOfLinenumbers;
      DWORD LvaToFirstLinenumber;
      DWORD RvaToFirstByteOfCode;
      DWORD RvaToLastByteOfCode;
      DWORD RvaToFirstByteOfData;
      DWORD RvaToLastByteOfData;
    } IMAGE_COFF_SYMBOLS_HEADER,*PIMAGE_COFF_SYMBOLS_HEADER;

#define FRAME_FPO 0
#define FRAME_TRAP 1
#define FRAME_TSS 2
#define FRAME_NONFPO 3

    typedef struct _FPO_DATA {
      DWORD ulOffStart;
      DWORD cbProcSize;
      DWORD cdwLocals;
      WORD cdwParams;
      WORD cbProlog : 8;
      WORD cbRegs : 3;
      WORD fHasSEH : 1;
      WORD fUseBP : 1;
      WORD reserved : 1;
      WORD cbFrame : 2;
    } FPO_DATA,*PFPO_DATA;
#define SIZEOF_RFPO_DATA 16

#define IMAGE_DEBUG_MISC_EXENAME 1

    typedef struct _IMAGE_DEBUG_MISC {
      DWORD DataType;
      DWORD Length;
      BOOLEAN Unicode;
      BYTE Reserved[3];
      BYTE Data[1];
    } IMAGE_DEBUG_MISC,*PIMAGE_DEBUG_MISC;

    typedef struct _IMAGE_FUNCTION_ENTRY {
      DWORD StartingAddress;
      DWORD EndingAddress;
      DWORD EndOfPrologue;
    } IMAGE_FUNCTION_ENTRY,*PIMAGE_FUNCTION_ENTRY;

    typedef struct _IMAGE_FUNCTION_ENTRY64 {
      ULONGLONG StartingAddress;
      ULONGLONG EndingAddress;
      __C89_NAMELESS union {
	ULONGLONG EndOfPrologue;
	ULONGLONG UnwindInfoAddress;
      } DUMMYUNIONNAME;
    } IMAGE_FUNCTION_ENTRY64,*PIMAGE_FUNCTION_ENTRY64;

    typedef struct _IMAGE_SEPARATE_DEBUG_HEADER {
      WORD Signature;
      WORD Flags;
      WORD Machine;
      WORD Characteristics;
      DWORD TimeDateStamp;
      DWORD CheckSum;
      DWORD ImageBase;
      DWORD SizeOfImage;
      DWORD NumberOfSections;
      DWORD ExportedNamesSize;
      DWORD DebugDirectorySize;
      DWORD SectionAlignment;
      DWORD Reserved[2];
    } IMAGE_SEPARATE_DEBUG_HEADER,*PIMAGE_SEPARATE_DEBUG_HEADER;

    typedef struct _NON_PAGED_DEBUG_INFO {
      WORD Signature;
      WORD Flags;
      DWORD Size;
      WORD Machine;
      WORD Characteristics;
      DWORD TimeDateStamp;
      DWORD CheckSum;
      DWORD SizeOfImage;
      ULONGLONG ImageBase;
    } NON_PAGED_DEBUG_INFO,*PNON_PAGED_DEBUG_INFO;

#define IMAGE_SEPARATE_DEBUG_SIGNATURE 0x4944
#define NON_PAGED_DEBUG_SIGNATURE 0x494E

#define IMAGE_SEPARATE_DEBUG_FLAGS_MASK 0x8000
#define IMAGE_SEPARATE_DEBUG_MISMATCH 0x8000

    typedef struct _ImageArchitectureHeader {
      unsigned int AmaskValue: 1;
      int Adummy1 : 7;
      unsigned int AmaskShift : 8;
      int Adummy2 : 16;
      DWORD FirstEntryRVA;
    } IMAGE_ARCHITECTURE_HEADER,*PIMAGE_ARCHITECTURE_HEADER;

    typedef struct _ImageArchitectureEntry {
      DWORD FixupInstRVA;
      DWORD NewInst;
    } IMAGE_ARCHITECTURE_ENTRY,*PIMAGE_ARCHITECTURE_ENTRY;
#include "poppack.h"

#define IMPORT_OBJECT_HDR_SIG2 0xffff

    typedef struct IMPORT_OBJECT_HEADER {
      WORD Sig1;
      WORD Sig2;
      WORD Version;
      WORD Machine;
      DWORD TimeDateStamp;
      DWORD SizeOfData;
      __C89_NAMELESS union {
	WORD Ordinal;
	WORD Hint;
      };
      WORD Type : 2;
      WORD NameType : 3;
      WORD Reserved : 11;
    } IMPORT_OBJECT_HEADER;

    typedef enum IMPORT_OBJECT_TYPE {
      IMPORT_OBJECT_CODE = 0,IMPORT_OBJECT_DATA = 1,IMPORT_OBJECT_CONST = 2
    } IMPORT_OBJECT_TYPE;

    typedef enum IMPORT_OBJECT_NAME_TYPE {
      IMPORT_OBJECT_ORDINAL = 0,IMPORT_OBJECT_NAME = 1,IMPORT_OBJECT_NAME_NO_PREFIX = 2,IMPORT_OBJECT_NAME_UNDECORATE = 3
    } IMPORT_OBJECT_NAME_TYPE;

#ifndef __IMAGE_COR20_HEADER_DEFINED__
#define __IMAGE_COR20_HEADER_DEFINED__
    typedef enum ReplacesCorHdrNumericDefines {
      COMIMAGE_FLAGS_ILONLY = 0x00000001,COMIMAGE_FLAGS_32BITREQUIRED = 0x00000002,COMIMAGE_FLAGS_IL_LIBRARY = 0x00000004,
      COMIMAGE_FLAGS_STRONGNAMESIGNED = 0x00000008,COMIMAGE_FLAGS_TRACKDEBUGDATA = 0x00010000,COR_VERSION_MAJOR_V2 = 2,
      COR_VERSION_MAJOR = COR_VERSION_MAJOR_V2,COR_VERSION_MINOR = 0,COR_DELETED_NAME_LENGTH = 8,COR_VTABLEGAP_NAME_LENGTH = 8,
      NATIVE_TYPE_MAX_CB = 1,COR_ILMETHOD_SECT_SMALL_MAX_DATASIZE= 0xFF,IMAGE_COR_MIH_METHODRVA = 0x01,IMAGE_COR_MIH_EHRVA = 0x02,
      IMAGE_COR_MIH_BASICBLOCK = 0x08,COR_VTABLE_32BIT =0x01,COR_VTABLE_64BIT =0x02,COR_VTABLE_FROM_UNMANAGED = 0x04,
      COR_VTABLE_CALL_MOST_DERIVED = 0x10,IMAGE_COR_EATJ_THUNK_SIZE = 32,MAX_CLASS_NAME =1024,MAX_PACKAGE_NAME = 1024
    } ReplacesCorHdrNumericDefines;

    typedef struct IMAGE_COR20_HEADER {
      DWORD cb;
      WORD MajorRuntimeVersion;
      WORD MinorRuntimeVersion;
      IMAGE_DATA_DIRECTORY MetaData;
      DWORD Flags;
      __C89_NAMELESS union {
	DWORD EntryPointToken;
	DWORD EntryPointRVA;
      } DUMMYUNIONNAME;
      IMAGE_DATA_DIRECTORY Resources;
      IMAGE_DATA_DIRECTORY StrongNameSignature;
      IMAGE_DATA_DIRECTORY CodeManagerTable;
      IMAGE_DATA_DIRECTORY VTableFixups;
      IMAGE_DATA_DIRECTORY ExportAddressTableJumps;
      IMAGE_DATA_DIRECTORY ManagedNativeHeader;
    } IMAGE_COR20_HEADER,*PIMAGE_COR20_HEADER;
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
    NTSYSAPI WORD NTAPI RtlCaptureStackBackTrace (DWORD FramesToSkip, DWORD FramesToCapture, PVOID *BackTrace, PDWORD BackTraceHash);
#endif
#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
    NTSYSAPI VOID NTAPI RtlCaptureContext (PCONTEXT ContextRecord);
    NTSYSAPI SIZE_T NTAPI RtlCompareMemory (const VOID *Source1, const VOID *Source2, SIZE_T Length);
#if defined (__x86_64__)
#if _WIN32_WINNT >= 0x0602
    NTSYSAPI DWORD NTAPI RtlAddGrowableFunctionTable (PVOID *DynamicTable, PRUNTIME_FUNCTION FunctionTable, DWORD EntryCount, DWORD MaximumEntryCount, ULONG_PTR RangeBase, ULONG_PTR RangeEnd);
    NTSYSAPI VOID NTAPI RtlGrowFunctionTable (PVOID DynamicTable, DWORD NewEntryCount);
    NTSYSAPI VOID NTAPI RtlDeleteGrowableFunctionTable (PVOID DynamicTable);
#endif
    NTSYSAPI BOOLEAN __cdecl RtlAddFunctionTable (PRUNTIME_FUNCTION FunctionTable, DWORD EntryCount, DWORD64 BaseAddress);
    NTSYSAPI BOOLEAN __cdecl RtlDeleteFunctionTable (PRUNTIME_FUNCTION FunctionTable);
    NTSYSAPI BOOLEAN __cdecl RtlInstallFunctionTableCallback (DWORD64 TableIdentifier, DWORD64 BaseAddress, DWORD Length, PGET_RUNTIME_FUNCTION_CALLBACK Callback, PVOID Context, PCWSTR OutOfProcessCallbackDll);
    NTSYSAPI VOID __cdecl RtlRestoreContext (PCONTEXT ContextRecord, struct _EXCEPTION_RECORD *ExceptionRecord);
#endif
#if defined (__arm__)
#if _WIN32_WINNT >= 0x0602
    NTSYSAPI DWORD NTAPI RtlAddGrowableFunctionTable (PVOID *DynamicTable, PRUNTIME_FUNCTION FunctionTable, DWORD EntryCount, DWORD MaximumEntryCount, ULONG_PTR RangeBase, ULONG_PTR RangeEnd);
    NTSYSAPI VOID NTAPI RtlGrowFunctionTable (PVOID DynamicTable, DWORD NewEntryCount);
    NTSYSAPI VOID NTAPI RtlDeleteGrowableFunctionTable (PVOID DynamicTable);
#endif
    NTSYSAPI BOOLEAN __cdecl RtlAddFunctionTable (PRUNTIME_FUNCTION FunctionTable, DWORD EntryCount, DWORD BaseAddress);
    NTSYSAPI BOOLEAN __cdecl RtlDeleteFunctionTable (PRUNTIME_FUNCTION FunctionTable);
    NTSYSAPI BOOLEAN __cdecl RtlInstallFunctionTableCallback (DWORD TableIdentifier, DWORD BaseAddress, DWORD Length, PGET_RUNTIME_FUNCTION_CALLBACK Callback, PVOID Context, PCWSTR OutOfProcessCallbackDll);
    NTSYSAPI VOID __cdecl RtlRestoreContext (PCONTEXT ContextRecord, struct _EXCEPTION_RECORD *ExceptionRecord);
#endif
#if defined (__aarch64__)
    NTSYSAPI DWORD NTAPI RtlAddGrowableFunctionTable (PVOID *DynamicTable, PRUNTIME_FUNCTION FunctionTable, DWORD EntryCount, DWORD MaximumEntryCount, ULONG_PTR RangeBase, ULONG_PTR RangeEnd);
    NTSYSAPI VOID NTAPI RtlGrowFunctionTable (PVOID DynamicTable, DWORD NewEntryCount);
    NTSYSAPI VOID NTAPI RtlDeleteGrowableFunctionTable (PVOID DynamicTable);
    NTSYSAPI BOOLEAN __cdecl RtlAddFunctionTable (PRUNTIME_FUNCTION FunctionTable, DWORD EntryCount, ULONG_PTR BaseAddress);
    NTSYSAPI BOOLEAN __cdecl RtlDeleteFunctionTable (PRUNTIME_FUNCTION FunctionTable);
    NTSYSAPI BOOLEAN __cdecl RtlInstallFunctionTableCallback (ULONG_PTR TableIdentifier, ULONG_PTR BaseAddress, DWORD Length, PGET_RUNTIME_FUNCTION_CALLBACK Callback, PVOID Context, PCWSTR OutOfProcessCallbackDll);
    NTSYSAPI VOID __cdecl RtlRestoreContext (PCONTEXT ContextRecord, struct _EXCEPTION_RECORD *ExceptionRecord);
#endif
#if defined (__ia64__)
    NTSYSAPI BOOLEAN NTAPI RtlAddFunctionTable (PRUNTIME_FUNCTION FunctionTable, DWORD EntryCount, ULONGLONG BaseAddress, ULONGLONG TargetGp);
    NTSYSAPI BOOLEAN NTAPI RtlDeleteFunctionTable (PRUNTIME_FUNCTION FunctionTable);
    NTSYSAPI BOOLEAN NTAPI RtlInstallFunctionTableCallback (DWORD64 TableIdentifier, DWORD64 BaseAddress, DWORD Length, DWORD64 TargetGp, PGET_RUNTIME_FUNCTION_CALLBACK Callback, PVOID Context, PCWSTR OutOfProcessCallbackDll);
    NTSYSAPI VOID NTAPI RtlRestoreContext (PCONTEXT ContextRecord, struct _EXCEPTION_RECORD *ExceptionRecord);
#endif

#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
    NTSYSAPI VOID NTAPI RtlUnwind (PVOID TargetFrame, PVOID TargetIp, PEXCEPTION_RECORD ExceptionRecord, PVOID ReturnValue);
    NTSYSAPI PVOID NTAPI RtlPcToFileHeader (PVOID PcValue, PVOID *BaseOfImage);
#if defined (__x86_64__)
    NTSYSAPI PRUNTIME_FUNCTION NTAPI RtlLookupFunctionEntry (DWORD64 ControlPc, PDWORD64 ImageBase, PUNWIND_HISTORY_TABLE HistoryTable);
    NTSYSAPI VOID NTAPI RtlUnwindEx (PVOID TargetFrame, PVOID TargetIp, PEXCEPTION_RECORD ExceptionRecord, PVOID ReturnValue, PCONTEXT ContextRecord, PUNWIND_HISTORY_TABLE HistoryTable);
    NTSYSAPI PEXCEPTION_ROUTINE NTAPI RtlVirtualUnwind (DWORD HandlerType, DWORD64 ImageBase, DWORD64 ControlPc, PRUNTIME_FUNCTION FunctionEntry, PCONTEXT ContextRecord, PVOID *HandlerData, PDWORD64 EstablisherFrame, PKNONVOLATILE_CONTEXT_POINTERS ContextPointers);
#endif
#if defined (__arm__)
    NTSYSAPI PRUNTIME_FUNCTION NTAPI RtlLookupFunctionEntry (ULONG_PTR ControlPc, PDWORD ImageBase, PUNWIND_HISTORY_TABLE HistoryTable);
    NTSYSAPI VOID NTAPI RtlUnwindEx (PVOID TargetFrame, PVOID TargetIp, PEXCEPTION_RECORD ExceptionRecord, PVOID ReturnValue, PCONTEXT ContextRecord, PUNWIND_HISTORY_TABLE HistoryTable);
    NTSYSAPI PEXCEPTION_ROUTINE NTAPI RtlVirtualUnwind (DWORD HandlerType, DWORD ImageBase, DWORD ControlPc, PRUNTIME_FUNCTION FunctionEntry, PCONTEXT ContextRecord, PVOID *HandlerData, PDWORD EstablisherFrame, PKNONVOLATILE_CONTEXT_POINTERS ContextPointers);
#endif
#if defined (__aarch64__)
    NTSYSAPI PRUNTIME_FUNCTION NTAPI RtlLookupFunctionEntry (ULONG_PTR ControlPc, PULONG_PTR ImageBase, PUNWIND_HISTORY_TABLE HistoryTable);
    NTSYSAPI VOID NTAPI RtlUnwindEx (PVOID TargetFrame, PVOID TargetIp, PEXCEPTION_RECORD ExceptionRecord, PVOID ReturnValue, PCONTEXT ContextRecord, PUNWIND_HISTORY_TABLE HistoryTable);
    NTSYSAPI PEXCEPTION_ROUTINE NTAPI RtlVirtualUnwind (DWORD HandlerType, ULONG_PTR ImageBase, ULONG_PTR ControlPc, PRUNTIME_FUNCTION FunctionEntry, PCONTEXT ContextRecord, PVOID *HandlerData, PULONG_PTR EstablisherFrame, PKNONVOLATILE_CONTEXT_POINTERS ContextPointers);
#endif
#if defined (__ia64__)
    NTSYSAPI PRUNTIME_FUNCTION NTAPI RtlLookupFunctionEntry (ULONGLONG ControlPc, PULONGLONG ImageBase, PULONGLONG TargetGp);
    NTSYSAPI VOID NTAPI RtlUnwindEx (FRAME_POINTERS TargetFrame, PVOID TargetIp, PEXCEPTION_RECORD ExceptionRecord, PVOID ReturnValue, PCONTEXT ContextRecord, PUNWIND_HISTORY_TABLE HistoryTable);
    NTSYSAPI ULONGLONG NTAPI RtlVirtualUnwind (ULONGLONG ImageBase, ULONGLONG ControlPc, PRUNTIME_FUNCTION FunctionEntry, PCONTEXT ContextRecord, PBOOLEAN InFunction, PFRAME_POINTERS EstablisherFrame, PKNONVOLATILE_CONTEXT_POINTERS ContextPointers);
#endif
#endif

#include <string.h>

#ifndef _SLIST_HEADER_
#define _SLIST_HEADER_

#if defined (_WIN64)
    typedef struct DECLSPEC_ALIGN (16) _SLIST_ENTRY {
      struct _SLIST_ENTRY *Next;
    } SLIST_ENTRY,*PSLIST_ENTRY;

    typedef union DECLSPEC_ALIGN (16) _SLIST_HEADER {
      __C89_NAMELESS struct {
	ULONGLONG Alignment;
	ULONGLONG Region;
      } DUMMYSTRUCTNAME;
      struct {
	ULONGLONG Depth:16;
	ULONGLONG Sequence:9;
	ULONGLONG NextEntry:39;
	ULONGLONG HeaderType:1;
	ULONGLONG Init:1;
	ULONGLONG Reserved:59;
	ULONGLONG Region:3;
      } Header8;
      struct {
	ULONGLONG Depth:16;
	ULONGLONG Sequence:48;
	ULONGLONG HeaderType:1;
	ULONGLONG Reserved:3;
	ULONGLONG NextEntry:60;
      } HeaderX64;
    } SLIST_HEADER,*PSLIST_HEADER;
#else  /* _WIN64 */
    typedef struct _SINGLE_LIST_ENTRY SLIST_ENTRY,*PSLIST_ENTRY;

    typedef union _SLIST_HEADER {
      ULONGLONG Alignment;
      __C89_NAMELESS struct {
	SLIST_ENTRY Next;
	WORD Depth;
	WORD Sequence;
      } DUMMYSTRUCTNAME;
    } SLIST_HEADER,*PSLIST_HEADER;
#endif /* _WIN64 */

#endif /* _SLIST_HEADER_ */

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
    NTSYSAPI VOID NTAPI RtlInitializeSListHead (PSLIST_HEADER ListHead);
    NTSYSAPI PSLIST_ENTRY NTAPI RtlFirstEntrySList (const SLIST_HEADER *ListHead);
    NTSYSAPI PSLIST_ENTRY NTAPI RtlInterlockedPopEntrySList (PSLIST_HEADER ListHead);
    NTSYSAPI PSLIST_ENTRY NTAPI RtlInterlockedPushEntrySList (PSLIST_HEADER ListHead, PSLIST_ENTRY ListEntry);
    NTSYSAPI PSLIST_ENTRY NTAPI RtlInterlockedPushListSListEx (PSLIST_HEADER ListHead, PSLIST_ENTRY List, PSLIST_ENTRY ListEnd, DWORD Count);
    NTSYSAPI PSLIST_ENTRY NTAPI RtlInterlockedFlushSList (PSLIST_HEADER ListHead);
    NTSYSAPI WORD NTAPI RtlQueryDepthSList (PSLIST_HEADER ListHead);
#endif

#ifndef _RTL_RUN_ONCE_DEF
#define _RTL_RUN_ONCE_DEF 1

typedef struct _RTL_RUN_ONCE { PVOID Ptr; } RTL_RUN_ONCE, *PRTL_RUN_ONCE;
typedef DWORD (WINAPI *PRTL_RUN_ONCE_INIT_FN)(PRTL_RUN_ONCE, PVOID, PVOID *);

#define RTL_RUN_ONCE_INIT {0}
#define RTL_RUN_ONCE_CHECK_ONLY __MSABI_LONG(1U)
#define RTL_RUN_ONCE_ASYNC __MSABI_LONG(2U)
#define RTL_RUN_ONCE_INIT_FAILED __MSABI_LONG(4U)
#define RTL_RUN_ONCE_CTX_RESERVED_BITS 2
#endif

  typedef struct _RTL_BARRIER {
    DWORD Reserved1;
    DWORD Reserved2;
    ULONG_PTR Reserved3[2];
    DWORD Reserved4;
    DWORD Reserved5;
  } RTL_BARRIER,*PRTL_BARRIER;

#define FAST_FAIL_LEGACY_GS_VIOLATION 0
#define FAST_FAIL_VTGUARD_CHECK_FAILURE 1
#define FAST_FAIL_STACK_COOKIE_CHECK_FAILURE 2
#define FAST_FAIL_CORRUPT_LIST_ENTRY 3
#define FAST_FAIL_INCORRECT_STACK 4
#define FAST_FAIL_INVALID_ARG 5
#define FAST_FAIL_GS_COOKIE_INIT 6
#define FAST_FAIL_FATAL_APP_EXIT 7
#define FAST_FAIL_RANGE_CHECK_FAILURE 8
#define FAST_FAIL_UNSAFE_REGISTRY_ACCESS 9
#define FAST_FAIL_INVALID_FAST_FAIL_CODE 0xffffffff

/* TODO: Check implementation of
   DECLSPEC_NORETURN VOID __fastfail (unsigned int); */

#define HEAP_NO_SERIALIZE 0x00000001
#define HEAP_GROWABLE 0x00000002
#define HEAP_GENERATE_EXCEPTIONS 0x00000004
#define HEAP_ZERO_MEMORY 0x00000008
#define HEAP_REALLOC_IN_PLACE_ONLY 0x00000010
#define HEAP_TAIL_CHECKING_ENABLED 0x00000020
#define HEAP_FREE_CHECKING_ENABLED 0x00000040
#define HEAP_DISABLE_COALESCE_ON_FREE 0x00000080
#define HEAP_CREATE_ALIGN_16 0x00010000
#define HEAP_CREATE_ENABLE_TRACING 0x00020000
#define HEAP_CREATE_ENABLE_EXECUTE 0x00040000
#define HEAP_MAXIMUM_TAG 0x0FFF
#define HEAP_PSEUDO_TAG_FLAG 0x8000
#define HEAP_TAG_SHIFT 18
/* Let this macro fail for non-desktop mode.  AFAIU this should be better an inline-function ... */
#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#define HEAP_MAKE_TAG_FLAGS(b,o) ((DWORD)((b) + ((o) << 18)))
#endif

#define IS_TEXT_UNICODE_ASCII16 0x0001
#define IS_TEXT_UNICODE_REVERSE_ASCII16 0x0010

#define IS_TEXT_UNICODE_STATISTICS 0x0002
#define IS_TEXT_UNICODE_REVERSE_STATISTICS 0x0020

#define IS_TEXT_UNICODE_CONTROLS 0x0004
#define IS_TEXT_UNICODE_REVERSE_CONTROLS 0x0040

#define IS_TEXT_UNICODE_SIGNATURE 0x0008
#define IS_TEXT_UNICODE_REVERSE_SIGNATURE 0x0080

#define IS_TEXT_UNICODE_ILLEGAL_CHARS 0x0100
#define IS_TEXT_UNICODE_ODD_LENGTH 0x0200
#define IS_TEXT_UNICODE_DBCS_LEADBYTE 0x0400
#define IS_TEXT_UNICODE_NULL_BYTES 0x1000

#define IS_TEXT_UNICODE_UNICODE_MASK 0x000F
#define IS_TEXT_UNICODE_REVERSE_MASK 0x00F0
#define IS_TEXT_UNICODE_NOT_UNICODE_MASK 0x0F00
#define IS_TEXT_UNICODE_NOT_ASCII_MASK 0xF000

#define COMPRESSION_FORMAT_NONE (0x0000)
#define COMPRESSION_FORMAT_DEFAULT (0x0001)
#define COMPRESSION_FORMAT_LZNT1 (0x0002)
#define COMPRESSION_FORMAT_XPRESS (0x0003)
#define COMPRESSION_FORMAT_XPRESS_HUFF (0x0004)
#define COMPRESSION_ENGINE_STANDARD (0x0000)
#define COMPRESSION_ENGINE_MAXIMUM (0x0100)
#define COMPRESSION_ENGINE_HIBER (0x0200)

#ifndef __CRT__NO_INLINE
#if _DBG_MEMCPY_INLINE_ && !defined(_MEMCPY_INLINE_) && !defined(_CRTBLD)
#define _MEMCPY_INLINE_
    __CRT_INLINE PVOID __cdecl memcpy_inline(void *dst,const void *src,size_t size) {
      if(((char *)dst > (char *)src) && ((char *)dst < ((char *)src + size))) {
	__debugbreak();
      }
      return memcpy(dst,src,size);
    }
#define memcpy memcpy_inline
#endif /* _DBG_MEMCPY_INLINE_ && !defined(_MEMCPY_INLINE_) && !defined(_CRTBLD) */
#endif /* !__CRT__NO_INLINE */

#define RtlEqualMemory(Destination,Source,Length) (!memcmp((Destination),(Source),(Length)))
#define RtlMoveMemory(Destination,Source,Length) memmove((Destination),(Source),(Length))
#define RtlCopyMemory(Destination,Source,Length) memcpy((Destination),(Source),(Length))
#define RtlFillMemory(Destination,Length,Fill) memset((Destination),(Fill),(Length))
#define RtlZeroMemory(Destination,Length) memset((Destination),0,(Length))

    PVOID WINAPI RtlSecureZeroMemory(PVOID ptr,SIZE_T cnt);

#if !defined (__CRT__NO_INLINE) && !defined (__WIDL__)
    __CRT_INLINE PVOID WINAPI RtlSecureZeroMemory(PVOID ptr,SIZE_T cnt) {
      volatile char *vptr =(volatile char *)ptr;
#ifdef __x86_64
      __stosb((PBYTE)((DWORD64)vptr),0,cnt);
#else
      while(cnt) {
	*vptr++ = 0;
	cnt--;
      }
#endif /* __x86_64 */
      return ptr;
    }
#endif /* !__CRT__NO_INLINE // !__WIDL__ */

    typedef struct _MESSAGE_RESOURCE_ENTRY {
      WORD Length;
      WORD Flags;
      BYTE Text[1];
    } MESSAGE_RESOURCE_ENTRY,*PMESSAGE_RESOURCE_ENTRY;

#define SEF_DACL_AUTO_INHERIT 0x01
#define SEF_SACL_AUTO_INHERIT 0x02
#define SEF_DEFAULT_DESCRIPTOR_FOR_OBJECT 0x04
#define SEF_AVOID_PRIVILEGE_CHECK 0x08
#define SEF_AVOID_OWNER_CHECK 0x10
#define SEF_DEFAULT_OWNER_FROM_PARENT 0x20
#define SEF_DEFAULT_GROUP_FROM_PARENT 0x40
#define SEF_MACL_NO_WRITE_UP 0x100
#define SEF_MACL_NO_READ_UP 0x200
#define SEF_MACL_NO_EXECUTE_UP 0x400
#define SEF_AVOID_OWNER_RESTRICTION 0x1000

#define SEF_MACL_VALID_FLAGS (SEF_MACL_NO_WRITE_UP | SEF_MACL_NO_READ_UP | SEF_MACL_NO_EXECUTE_UP)

#define MESSAGE_RESOURCE_UNICODE 0x0001

    typedef struct _MESSAGE_RESOURCE_BLOCK {
      DWORD LowId;
      DWORD HighId;
      DWORD OffsetToEntries;
    } MESSAGE_RESOURCE_BLOCK,*PMESSAGE_RESOURCE_BLOCK;

    typedef struct _MESSAGE_RESOURCE_DATA {
      DWORD NumberOfBlocks;
      MESSAGE_RESOURCE_BLOCK Blocks[1];
    } MESSAGE_RESOURCE_DATA,*PMESSAGE_RESOURCE_DATA;

    typedef struct _OSVERSIONINFOA {
      DWORD dwOSVersionInfoSize;
      DWORD dwMajorVersion;
      DWORD dwMinorVersion;
      DWORD dwBuildNumber;
      DWORD dwPlatformId;
      CHAR szCSDVersion[128];
    } OSVERSIONINFOA,*POSVERSIONINFOA,*LPOSVERSIONINFOA;

    typedef struct _OSVERSIONINFOW {
      DWORD dwOSVersionInfoSize;
      DWORD dwMajorVersion;
      DWORD dwMinorVersion;
      DWORD dwBuildNumber;
      DWORD dwPlatformId;
      WCHAR szCSDVersion[128];
    } OSVERSIONINFOW,*POSVERSIONINFOW,*LPOSVERSIONINFOW,RTL_OSVERSIONINFOW,*PRTL_OSVERSIONINFOW;

    __MINGW_TYPEDEF_AW(OSVERSIONINFO)
    __MINGW_TYPEDEF_AW(POSVERSIONINFO)
    __MINGW_TYPEDEF_AW(LPOSVERSIONINFO)

    typedef struct _OSVERSIONINFOEXA {
      DWORD dwOSVersionInfoSize;
      DWORD dwMajorVersion;
      DWORD dwMinorVersion;
      DWORD dwBuildNumber;
      DWORD dwPlatformId;
      CHAR szCSDVersion[128];
      WORD wServicePackMajor;
      WORD wServicePackMinor;
      WORD wSuiteMask;
      BYTE wProductType;
      BYTE wReserved;
    } OSVERSIONINFOEXA,*POSVERSIONINFOEXA,*LPOSVERSIONINFOEXA;

    typedef struct _OSVERSIONINFOEXW {
      DWORD dwOSVersionInfoSize;
      DWORD dwMajorVersion;
      DWORD dwMinorVersion;
      DWORD dwBuildNumber;
      DWORD dwPlatformId;
      WCHAR szCSDVersion[128];
      WORD wServicePackMajor;
      WORD wServicePackMinor;
      WORD wSuiteMask;
      BYTE wProductType;
      BYTE wReserved;
    } OSVERSIONINFOEXW,*POSVERSIONINFOEXW,*LPOSVERSIONINFOEXW,RTL_OSVERSIONINFOEXW,*PRTL_OSVERSIONINFOEXW;

    __MINGW_TYPEDEF_AW(OSVERSIONINFOEX)
    __MINGW_TYPEDEF_AW(POSVERSIONINFOEX)
    __MINGW_TYPEDEF_AW(LPOSVERSIONINFOEX)

#define VER_EQUAL 1
#define VER_GREATER 2
#define VER_GREATER_EQUAL 3
#define VER_LESS 4
#define VER_LESS_EQUAL 5
#define VER_AND 6
#define VER_OR 7

#define VER_CONDITION_MASK 7
#define VER_NUM_BITS_PER_CONDITION_MASK 3

#define VER_MINORVERSION 0x0000001
#define VER_MAJORVERSION 0x0000002
#define VER_BUILDNUMBER 0x0000004
#define VER_PLATFORMID 0x0000008
#define VER_SERVICEPACKMINOR 0x0000010
#define VER_SERVICEPACKMAJOR 0x0000020
#define VER_SUITENAME 0x0000040
#define VER_PRODUCT_TYPE 0x0000080

#define VER_NT_WORKSTATION 0x0000001
#define VER_NT_DOMAIN_CONTROLLER 0x0000002
#define VER_NT_SERVER 0x0000003

#define VER_PLATFORM_WIN32s 0
#define VER_PLATFORM_WIN32_WINDOWS 1
#define VER_PLATFORM_WIN32_NT 2

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#if !defined (_WINBASE_) && !defined (__WIDL__)
    NTSYSAPI ULONGLONG NTAPI VerSetConditionMask (ULONGLONG ConditionMask, DWORD TypeMask, BYTE Condition);
#endif

#define VER_SET_CONDITION(_m_,_t_,_c_) ((_m_) = VerSetConditionMask((_m_),(_t_),(_c_)))

#if _WIN32_WINNT >= 0x0600 && !defined (__WIDL__)
    NTSYSAPI BOOLEAN NTAPI RtlGetProductInfo (DWORD OSMajorVersion, DWORD OSMinorVersion, DWORD SpMajorVersion, DWORD SpMinorVersion, PDWORD ReturnedProductType);
#endif
#endif

#define RTL_UMS_VERSION (0x0100)

    typedef enum _RTL_UMS_THREAD_INFO_CLASS {
      UmsThreadInvalidInfoClass = 0,
      UmsThreadUserContext,
      UmsThreadPriority,
      UmsThreadAffinity,
      UmsThreadTeb,
      UmsThreadIsSuspended,
      UmsThreadIsTerminated,
      UmsThreadMaxInfoClass
    } RTL_UMS_THREAD_INFO_CLASS,*PRTL_UMS_THREAD_INFO_CLASS;

    typedef enum _RTL_UMS_SCHEDULER_REASON {
      UmsSchedulerStartup = 0,
      UmsSchedulerThreadBlocked,
      UmsSchedulerThreadYield,
    } RTL_UMS_SCHEDULER_REASON,*PRTL_UMS_SCHEDULER_REASON;

    typedef VOID NTAPI RTL_UMS_SCHEDULER_ENTRY_POINT (RTL_UMS_SCHEDULER_REASON Reason, ULONG_PTR ActivationPayload, PVOID SchedulerParam);
    typedef RTL_UMS_SCHEDULER_ENTRY_POINT *PRTL_UMS_SCHEDULER_ENTRY_POINT;

#if _WIN32_WINNT >= 0x0602
#ifndef IS_VALIDATION_ENABLED
#define IS_VALIDATION_ENABLED(C, L) ((L) & (C))
#define VRL_PREDEFINED_CLASS_BEGIN (1)
#define VRL_CUSTOM_CLASS_BEGIN (1 << 8)
#define VRL_CLASS_CONSISTENCY (VRL_PREDEFINED_CLASS_BEGIN)
#define VRL_ENABLE_KERNEL_BREAKS (1 << 31)
#endif

#define CTMF_INCLUDE_APPCONTAINER __MSABI_LONG(0x1U)
#define CTMF_VALID_FLAGS (CTMF_INCLUDE_APPCONTAINER)

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
    NTSYSAPI DWORD NTAPI RtlCrc32 (const void *Buffer, size_t Size, DWORD InitialCrc);
    NTSYSAPI ULONGLONG NTAPI RtlCrc64 (const void *Buffer, size_t Size, ULONGLONG InitialCrc);
#endif
#endif

    typedef struct _RTL_CRITICAL_SECTION_DEBUG {
      WORD Type;
      WORD CreatorBackTraceIndex;
      struct _RTL_CRITICAL_SECTION *CriticalSection;
      LIST_ENTRY ProcessLocksList;
      DWORD EntryCount;
      DWORD ContentionCount;
      DWORD Flags;
      WORD CreatorBackTraceIndexHigh;
      WORD SpareWORD;
    } RTL_CRITICAL_SECTION_DEBUG,*PRTL_CRITICAL_SECTION_DEBUG,RTL_RESOURCE_DEBUG,*PRTL_RESOURCE_DEBUG;

#define RTL_CRITSECT_TYPE 0
#define RTL_RESOURCE_TYPE 1

#define RTL_CRITICAL_SECTION_FLAG_NO_DEBUG_INFO 0x01000000
#define RTL_CRITICAL_SECTION_FLAG_DYNAMIC_SPIN 0x02000000
#define RTL_CRITICAL_SECTION_FLAG_STATIC_INIT 0x04000000
#define RTL_CRITICAL_SECTION_FLAG_RESOURCE_TYPE 0x08000000
#define RTL_CRITICAL_SECTION_FLAG_FORCE_DEBUG_INFO 0x10000000
#define RTL_CRITICAL_SECTION_ALL_FLAG_BITS 0xff000000

#define RTL_CRITICAL_SECTION_FLAG_RESERVED (RTL_CRITICAL_SECTION_ALL_FLAG_BITS & (~(RTL_CRITICAL_SECTION_FLAG_NO_DEBUG_INFO | RTL_CRITICAL_SECTION_FLAG_DYNAMIC_SPIN | RTL_CRITICAL_SECTION_FLAG_STATIC_INIT | RTL_CRITICAL_SECTION_FLAG_RESOURCE_TYPE | RTL_CRITICAL_SECTION_FLAG_FORCE_DEBUG_INFO)))

#define RTL_CRITICAL_SECTION_DEBUG_FLAG_STATIC_INIT 0x00000001

#include <pshpack8.h>
    typedef struct _RTL_CRITICAL_SECTION {
      PRTL_CRITICAL_SECTION_DEBUG DebugInfo;
      LONG LockCount;
      LONG RecursionCount;
      HANDLE OwningThread;
      HANDLE LockSemaphore;
      ULONG_PTR SpinCount;
    } RTL_CRITICAL_SECTION,*PRTL_CRITICAL_SECTION;
#include <poppack.h>

    typedef struct _RTL_SRWLOCK { PVOID Ptr; } RTL_SRWLOCK,*PRTL_SRWLOCK;
    typedef struct _RTL_CONDITION_VARIABLE { PVOID Ptr; } RTL_CONDITION_VARIABLE,*PRTL_CONDITION_VARIABLE;

#define RTL_SRWLOCK_INIT {0}
#define RTL_CONDITION_VARIABLE_INIT {0}

#define RTL_CONDITION_VARIABLE_LOCKMODE_SHARED 0x1

    typedef VOID (NTAPI *PAPCFUNC) (ULONG_PTR Parameter);
    typedef LONG (NTAPI *PVECTORED_EXCEPTION_HANDLER) (struct _EXCEPTION_POINTERS *ExceptionInfo);

    typedef enum _HEAP_INFORMATION_CLASS {
      HeapCompatibilityInformation,
      HeapEnableTerminationOnCorruption
    } HEAP_INFORMATION_CLASS;

    typedef VOID (NTAPI *WORKERCALLBACKFUNC) (PVOID);
    typedef VOID (NTAPI *APC_CALLBACK_FUNCTION) (DWORD, PVOID, PVOID);
    typedef VOID (NTAPI *WAITORTIMERCALLBACKFUNC) (PVOID, BOOLEAN);
    typedef WAITORTIMERCALLBACKFUNC WAITORTIMERCALLBACK;
    typedef VOID (NTAPI *PFLS_CALLBACK_FUNCTION) (PVOID lpFlsData);
    typedef BOOLEAN (NTAPI *PSECURE_MEMORY_CACHE_CALLBACK) (PVOID Addr, SIZE_T Range);

#define WT_EXECUTEDEFAULT 0x00000000
#define WT_EXECUTEINIOTHREAD 0x00000001
#define WT_EXECUTEINUITHREAD 0x00000002
#define WT_EXECUTEINWAITTHREAD 0x00000004
#define WT_EXECUTEONLYONCE 0x00000008
#define WT_EXECUTEINTIMERTHREAD 0x00000020
#define WT_EXECUTELONGFUNCTION 0x00000010
#define WT_EXECUTEINPERSISTENTIOTHREAD 0x00000040
#define WT_EXECUTEINPERSISTENTTHREAD 0x00000080
#define WT_TRANSFER_IMPERSONATION 0x00000100

#define WT_SET_MAX_THREADPOOL_THREADS(Flags, Limit) ((Flags) |= (Limit) << 16)

#define WT_EXECUTEDELETEWAIT 0x00000008
#define WT_EXECUTEINLONGTHREAD 0x00000010

    typedef enum _ACTIVATION_CONTEXT_INFO_CLASS {
      ActivationContextBasicInformation = 1,
      ActivationContextDetailedInformation = 2,
      AssemblyDetailedInformationInActivationContext = 3,
      FileInformationInAssemblyOfAssemblyInActivationContext = 4,
      RunlevelInformationInActivationContext = 5,
      CompatibilityInformationInActivationContext = 6,
      ActivationContextManifestResourceName = 7,
      MaxActivationContextInfoClass,
      AssemblyDetailedInformationInActivationContxt = 3,
      FileInformationInAssemblyOfAssemblyInActivationContxt = 4
    } ACTIVATION_CONTEXT_INFO_CLASS;

    typedef enum {
      ACTCTX_RUN_LEVEL_UNSPECIFIED = 0,
      ACTCTX_RUN_LEVEL_AS_INVOKER,
      ACTCTX_RUN_LEVEL_HIGHEST_AVAILABLE,
      ACTCTX_RUN_LEVEL_REQUIRE_ADMIN,
      ACTCTX_RUN_LEVEL_NUMBERS
    } ACTCTX_REQUESTED_RUN_LEVEL;

    typedef enum {
      ACTCTX_COMPATIBILITY_ELEMENT_TYPE_UNKNOWN = 0,
      ACTCTX_COMPATIBILITY_ELEMENT_TYPE_OS,
      ACTCTX_COMPATIBILITY_ELEMENT_TYPE_MITIGATION
    } ACTCTX_COMPATIBILITY_ELEMENT_TYPE;

    typedef struct _ACTIVATION_CONTEXT_QUERY_INDEX {
      DWORD ulAssemblyIndex;
      DWORD ulFileIndexInAssembly;
    } ACTIVATION_CONTEXT_QUERY_INDEX,*PACTIVATION_CONTEXT_QUERY_INDEX;

    typedef struct _ASSEMBLY_FILE_DETAILED_INFORMATION {
      DWORD ulFlags;
      DWORD ulFilenameLength;
      DWORD ulPathLength;
      PCWSTR lpFileName;
      PCWSTR lpFilePath;
    } ASSEMBLY_FILE_DETAILED_INFORMATION,*PASSEMBLY_FILE_DETAILED_INFORMATION;

    typedef struct _ACTIVATION_CONTEXT_ASSEMBLY_DETAILED_INFORMATION {
      DWORD ulFlags;
      DWORD ulEncodedAssemblyIdentityLength;
      DWORD ulManifestPathType;
      DWORD ulManifestPathLength;
      LARGE_INTEGER liManifestLastWriteTime;
      DWORD ulPolicyPathType;
      DWORD ulPolicyPathLength;
      LARGE_INTEGER liPolicyLastWriteTime;
      DWORD ulMetadataSatelliteRosterIndex;
      DWORD ulManifestVersionMajor;
      DWORD ulManifestVersionMinor;
      DWORD ulPolicyVersionMajor;
      DWORD ulPolicyVersionMinor;
      DWORD ulAssemblyDirectoryNameLength;
      PCWSTR lpAssemblyEncodedAssemblyIdentity;
      PCWSTR lpAssemblyManifestPath;
      PCWSTR lpAssemblyPolicyPath;
      PCWSTR lpAssemblyDirectoryName;
      DWORD ulFileCount;
    } ACTIVATION_CONTEXT_ASSEMBLY_DETAILED_INFORMATION,*PACTIVATION_CONTEXT_ASSEMBLY_DETAILED_INFORMATION;

    typedef struct _ACTIVATION_CONTEXT_RUN_LEVEL_INFORMATION {
      DWORD ulFlags;
      ACTCTX_REQUESTED_RUN_LEVEL RunLevel;
      DWORD UiAccess;
    } ACTIVATION_CONTEXT_RUN_LEVEL_INFORMATION,*PACTIVATION_CONTEXT_RUN_LEVEL_INFORMATION;

    typedef struct _COMPATIBILITY_CONTEXT_ELEMENT {
      GUID Id;
      ACTCTX_COMPATIBILITY_ELEMENT_TYPE Type;
    } COMPATIBILITY_CONTEXT_ELEMENT,*PCOMPATIBILITY_CONTEXT_ELEMENT;

/*Vista: {e2011457-1546-43c5-a5fe-008deee3d3f0}*/
/*Seven: {35138b9a-5d96-4fbd-8e2d-a2440225f93a}*/
    typedef struct _ACTIVATION_CONTEXT_COMPATIBILITY_INFORMATION {
      DWORD ElementCount;
      COMPATIBILITY_CONTEXT_ELEMENT Elements[];
    } ACTIVATION_CONTEXT_COMPATIBILITY_INFORMATION,*PACTIVATION_CONTEXT_COMPATIBILITY_INFORMATION;

#define MAX_SUPPORTED_OS_NUM (4)

    typedef struct _SUPPORTED_OS_INFO {
      WORD OsCount;
      WORD MitigationExist;
      WORD OsList[MAX_SUPPORTED_OS_NUM];
    } SUPPORTED_OS_INFO,*PSUPPORTED_OS_INFO;

    typedef struct _ACTIVATION_CONTEXT_DETAILED_INFORMATION {
      DWORD dwFlags;
      DWORD ulFormatVersion;
      DWORD ulAssemblyCount;
      DWORD ulRootManifestPathType;
      DWORD ulRootManifestPathChars;
      DWORD ulRootConfigurationPathType;
      DWORD ulRootConfigurationPathChars;
      DWORD ulAppDirPathType;
      DWORD ulAppDirPathChars;
      PCWSTR lpRootManifestPath;
      PCWSTR lpRootConfigurationPath;
      PCWSTR lpAppDirPath;
    } ACTIVATION_CONTEXT_DETAILED_INFORMATION,*PACTIVATION_CONTEXT_DETAILED_INFORMATION;

    typedef const struct _ACTIVATION_CONTEXT_QUERY_INDEX *PCACTIVATION_CONTEXT_QUERY_INDEX;
    typedef const ASSEMBLY_FILE_DETAILED_INFORMATION *PCASSEMBLY_FILE_DETAILED_INFORMATION;
    typedef const struct _ACTIVATION_CONTEXT_ASSEMBLY_DETAILED_INFORMATION *PCACTIVATION_CONTEXT_ASSEMBLY_DETAILED_INFORMATION;
    typedef const struct _ACTIVATION_CONTEXT_RUN_LEVEL_INFORMATION *PCACTIVATION_CONTEXT_RUN_LEVEL_INFORMATION;
    typedef const struct _COMPATIBILITY_CONTEXT_ELEMENT *PCCOMPATIBILITY_CONTEXT_ELEMENT;
    typedef const struct _ACTIVATION_CONTEXT_COMPATIBILITY_INFORMATION *PCACTIVATION_CONTEXT_COMPATIBILITY_INFORMATION;
    typedef const struct _ACTIVATION_CONTEXT_DETAILED_INFORMATION *PCACTIVATION_CONTEXT_DETAILED_INFORMATION;

#define ACTIVATIONCONTEXTINFOCLASS ACTIVATION_CONTEXT_INFO_CLASS

#define ACTIVATION_CONTEXT_PATH_TYPE_NONE (1)
#define ACTIVATION_CONTEXT_PATH_TYPE_WIN32_FILE (2)
#define ACTIVATION_CONTEXT_PATH_TYPE_URL (3)
#define ACTIVATION_CONTEXT_PATH_TYPE_ASSEMBLYREF (4)

#define _ASSEMBLY_DLL_REDIRECTION_DETAILED_INFORMATION _ASSEMBLY_FILE_DETAILED_INFORMATION
#define ASSEMBLY_DLL_REDIRECTION_DETAILED_INFORMATION ASSEMBLY_FILE_DETAILED_INFORMATION
#define PASSEMBLY_DLL_REDIRECTION_DETAILED_INFORMATION PASSEMBLY_FILE_DETAILED_INFORMATION
#define PCASSEMBLY_DLL_REDIRECTION_DETAILED_INFORMATION PCASSEMBLY_FILE_DETAILED_INFORMATION
#define INVALID_OS_COUNT (0xffff)

#define CREATE_BOUNDARY_DESCRIPTOR_ADD_APPCONTAINER_SID 0x1

    typedef VOID (NTAPI *RTL_VERIFIER_DLL_LOAD_CALLBACK) (PWSTR DllName,PVOID DllBase,SIZE_T DllSize,PVOID Reserved);
    typedef VOID (NTAPI *RTL_VERIFIER_DLL_UNLOAD_CALLBACK) (PWSTR DllName,PVOID DllBase,SIZE_T DllSize,PVOID Reserved);
    typedef VOID (NTAPI *RTL_VERIFIER_NTDLLHEAPFREE_CALLBACK)(PVOID AllocationBase,SIZE_T AllocationSize);

    typedef struct _RTL_VERIFIER_THUNK_DESCRIPTOR {
      PCHAR ThunkName;
      PVOID ThunkOldAddress;
      PVOID ThunkNewAddress;
    } RTL_VERIFIER_THUNK_DESCRIPTOR,*PRTL_VERIFIER_THUNK_DESCRIPTOR;

    typedef struct _RTL_VERIFIER_DLL_DESCRIPTOR {
      PWCHAR DllName;
      DWORD DllFlags;
      PVOID DllAddress;
      PRTL_VERIFIER_THUNK_DESCRIPTOR DllThunks;
    } RTL_VERIFIER_DLL_DESCRIPTOR,*PRTL_VERIFIER_DLL_DESCRIPTOR;

    typedef struct _RTL_VERIFIER_PROVIDER_DESCRIPTOR {
      DWORD Length;
      PRTL_VERIFIER_DLL_DESCRIPTOR ProviderDlls;
      RTL_VERIFIER_DLL_LOAD_CALLBACK ProviderDllLoadCallback;
      RTL_VERIFIER_DLL_UNLOAD_CALLBACK ProviderDllUnloadCallback;
      PWSTR VerifierImage;
      DWORD VerifierFlags;
      DWORD VerifierDebug;
      PVOID RtlpGetStackTraceAddress;
      PVOID RtlpDebugPageHeapCreate;
      PVOID RtlpDebugPageHeapDestroy;
      RTL_VERIFIER_NTDLLHEAPFREE_CALLBACK ProviderNtdllHeapFreeCallback;
    } RTL_VERIFIER_PROVIDER_DESCRIPTOR,*PRTL_VERIFIER_PROVIDER_DESCRIPTOR;

#define RTL_VRF_FLG_FULL_PAGE_HEAP 0x00000001
#define RTL_VRF_FLG_RESERVED_DONOTUSE 0x00000002
#define RTL_VRF_FLG_HANDLE_CHECKS 0x00000004
#define RTL_VRF_FLG_STACK_CHECKS 0x00000008
#define RTL_VRF_FLG_APPCOMPAT_CHECKS 0x00000010
#define RTL_VRF_FLG_TLS_CHECKS 0x00000020
#define RTL_VRF_FLG_DIRTY_STACKS 0x00000040
#define RTL_VRF_FLG_RPC_CHECKS 0x00000080
#define RTL_VRF_FLG_COM_CHECKS 0x00000100
#define RTL_VRF_FLG_DANGEROUS_APIS 0x00000200
#define RTL_VRF_FLG_RACE_CHECKS 0x00000400
#define RTL_VRF_FLG_DEADLOCK_CHECKS 0x00000800
#define RTL_VRF_FLG_FIRST_CHANCE_EXCEPTION_CHECKS 0x00001000
#define RTL_VRF_FLG_VIRTUAL_MEM_CHECKS 0x00002000
#define RTL_VRF_FLG_ENABLE_LOGGING 0x00004000
#define RTL_VRF_FLG_FAST_FILL_HEAP 0x00008000
#define RTL_VRF_FLG_VIRTUAL_SPACE_TRACKING 0x00010000
#define RTL_VRF_FLG_ENABLED_SYSTEM_WIDE 0x00020000
#define RTL_VRF_FLG_MISCELLANEOUS_CHECKS 0x00020000
#define RTL_VRF_FLG_LOCK_CHECKS 0x00040000

#define APPLICATION_VERIFIER_INTERNAL_ERROR 0x80000000
#define APPLICATION_VERIFIER_INTERNAL_WARNING 0x40000000
#define APPLICATION_VERIFIER_NO_BREAK 0x20000000
#define APPLICATION_VERIFIER_CONTINUABLE_BREAK 0x10000000

#define APPLICATION_VERIFIER_UNKNOWN_ERROR 0x0001
#define APPLICATION_VERIFIER_ACCESS_VIOLATION 0x0002
#define APPLICATION_VERIFIER_UNSYNCHRONIZED_ACCESS 0x0003
#define APPLICATION_VERIFIER_EXTREME_SIZE_REQUEST 0x0004
#define APPLICATION_VERIFIER_BAD_HEAP_HANDLE 0x0005
#define APPLICATION_VERIFIER_SWITCHED_HEAP_HANDLE 0x0006
#define APPLICATION_VERIFIER_DOUBLE_FREE 0x0007
#define APPLICATION_VERIFIER_CORRUPTED_HEAP_BLOCK 0x0008
#define APPLICATION_VERIFIER_DESTROY_PROCESS_HEAP 0x0009
#define APPLICATION_VERIFIER_UNEXPECTED_EXCEPTION 0x000A
#define APPLICATION_VERIFIER_CORRUPTED_HEAP_BLOCK_EXCEPTION_RAISED_FOR_HEADER 0x000B
#define APPLICATION_VERIFIER_CORRUPTED_HEAP_BLOCK_EXCEPTION_RAISED_FOR_PROBING 0x000C
#define APPLICATION_VERIFIER_CORRUPTED_HEAP_BLOCK_HEADER 0x000D
#define APPLICATION_VERIFIER_CORRUPTED_FREED_HEAP_BLOCK 0x000E
#define APPLICATION_VERIFIER_CORRUPTED_HEAP_BLOCK_SUFFIX 0x000F
#define APPLICATION_VERIFIER_CORRUPTED_HEAP_BLOCK_START_STAMP 0x0010
#define APPLICATION_VERIFIER_CORRUPTED_HEAP_BLOCK_END_STAMP 0x0011
#define APPLICATION_VERIFIER_CORRUPTED_HEAP_BLOCK_PREFIX 0x0012
#define APPLICATION_VERIFIER_FIRST_CHANCE_ACCESS_VIOLATION 0x0013
#define APPLICATION_VERIFIER_CORRUPTED_HEAP_LIST 0x0014

#define APPLICATION_VERIFIER_TERMINATE_THREAD_CALL 0x0100
#define APPLICATION_VERIFIER_STACK_OVERFLOW 0x0101
#define APPLICATION_VERIFIER_INVALID_EXIT_PROCESS_CALL 0x0102

#define APPLICATION_VERIFIER_EXIT_THREAD_OWNS_LOCK 0x0200
#define APPLICATION_VERIFIER_LOCK_IN_UNLOADED_DLL 0x0201
#define APPLICATION_VERIFIER_LOCK_IN_FREED_HEAP 0x0202
#define APPLICATION_VERIFIER_LOCK_DOUBLE_INITIALIZE 0x0203
#define APPLICATION_VERIFIER_LOCK_IN_FREED_MEMORY 0x0204
#define APPLICATION_VERIFIER_LOCK_CORRUPTED 0x0205
#define APPLICATION_VERIFIER_LOCK_INVALID_OWNER 0x0206
#define APPLICATION_VERIFIER_LOCK_INVALID_RECURSION_COUNT 0x0207
#define APPLICATION_VERIFIER_LOCK_INVALID_LOCK_COUNT 0x0208
#define APPLICATION_VERIFIER_LOCK_OVER_RELEASED 0x0209
#define APPLICATION_VERIFIER_LOCK_NOT_INITIALIZED 0x0210
#define APPLICATION_VERIFIER_LOCK_ALREADY_INITIALIZED 0x0211
#define APPLICATION_VERIFIER_LOCK_IN_FREED_VMEM 0x0212
#define APPLICATION_VERIFIER_LOCK_IN_UNMAPPED_MEM 0x0213
#define APPLICATION_VERIFIER_THREAD_NOT_LOCK_OWNER 0x0214

#define APPLICATION_VERIFIER_INVALID_HANDLE 0x0300
#define APPLICATION_VERIFIER_INVALID_TLS_VALUE 0x0301
#define APPLICATION_VERIFIER_INCORRECT_WAIT_CALL 0x0302
#define APPLICATION_VERIFIER_NULL_HANDLE 0x0303
#define APPLICATION_VERIFIER_WAIT_IN_DLLMAIN 0x0304

#define APPLICATION_VERIFIER_COM_ERROR 0x0400
#define APPLICATION_VERIFIER_COM_API_IN_DLLMAIN 0x0401
#define APPLICATION_VERIFIER_COM_UNHANDLED_EXCEPTION 0x0402
#define APPLICATION_VERIFIER_COM_UNBALANCED_COINIT 0x0403
#define APPLICATION_VERIFIER_COM_UNBALANCED_OLEINIT 0x0404
#define APPLICATION_VERIFIER_COM_UNBALANCED_SWC 0x0405
#define APPLICATION_VERIFIER_COM_NULL_DACL 0x0406
#define APPLICATION_VERIFIER_COM_UNSAFE_IMPERSONATION 0x0407
#define APPLICATION_VERIFIER_COM_SMUGGLED_WRAPPER 0x0408
#define APPLICATION_VERIFIER_COM_SMUGGLED_PROXY 0x0409
#define APPLICATION_VERIFIER_COM_CF_SUCCESS_WITH_NULL 0x040A
#define APPLICATION_VERIFIER_COM_GCO_SUCCESS_WITH_NULL 0x040B
#define APPLICATION_VERIFIER_COM_OBJECT_IN_FREED_MEMORY 0x040C
#define APPLICATION_VERIFIER_COM_OBJECT_IN_UNLOADED_DLL 0x040D
#define APPLICATION_VERIFIER_COM_VTBL_IN_FREED_MEMORY 0x040E
#define APPLICATION_VERIFIER_COM_VTBL_IN_UNLOADED_DLL 0x040F
#define APPLICATION_VERIFIER_COM_HOLDING_LOCKS_ON_CALL 0x0410

#define APPLICATION_VERIFIER_RPC_ERROR 0x0500

#define APPLICATION_VERIFIER_INVALID_FREEMEM 0x0600
#define APPLICATION_VERIFIER_INVALID_ALLOCMEM 0x0601
#define APPLICATION_VERIFIER_INVALID_MAPVIEW 0x0602
#define APPLICATION_VERIFIER_PROBE_INVALID_ADDRESS 0x0603
#define APPLICATION_VERIFIER_PROBE_FREE_MEM 0x0604
#define APPLICATION_VERIFIER_PROBE_GUARD_PAGE 0x0605
#define APPLICATION_VERIFIER_PROBE_NULL 0x0606
#define APPLICATION_VERIFIER_PROBE_INVALID_START_OR_SIZE 0x0607
#define APPLICATION_VERIFIER_SIZE_HEAP_UNEXPECTED_EXCEPTION 0x0618

#define VERIFIER_STOP(Code,Msg,P1,S1,P2,S2,P3,S3,P4,S4) { RtlApplicationVerifierStop ((Code),(Msg),(ULONG_PTR)(P1),(S1),(ULONG_PTR)(P2),(S2),(ULONG_PTR)(P3),(S3),(ULONG_PTR)(P4),(S4)); }

    VOID NTAPI RtlApplicationVerifierStop(ULONG_PTR Code,PSTR Message,ULONG_PTR Param1,PSTR Description1,ULONG_PTR Param2,PSTR Description2,ULONG_PTR Param3,PSTR Description3,ULONG_PTR Param4,PSTR Description4);
    NTSYSAPI DWORD NTAPI RtlSetHeapInformation(PVOID HeapHandle,HEAP_INFORMATION_CLASS HeapInformationClass,PVOID HeapInformation,SIZE_T HeapInformationLength);
    NTSYSAPI DWORD NTAPI RtlQueryHeapInformation(PVOID HeapHandle,HEAP_INFORMATION_CLASS HeapInformationClass,PVOID HeapInformation,SIZE_T HeapInformationLength,PSIZE_T ReturnLength);
    DWORD NTAPI RtlMultipleAllocateHeap(PVOID HeapHandle,DWORD Flags,SIZE_T Size,DWORD Count,PVOID *Array);
    DWORD NTAPI RtlMultipleFreeHeap(PVOID HeapHandle,DWORD Flags,DWORD Count,PVOID *Array);

    typedef struct _HARDWARE_COUNTER_DATA {
      HARDWARE_COUNTER_TYPE Type;
      DWORD Reserved;
      DWORD64 Value;
    } HARDWARE_COUNTER_DATA,*PHARDWARE_COUNTER_DATA;

    typedef struct _PERFORMANCE_DATA {
      WORD Size;
      BYTE Version;
      BYTE HwCountersCount;
      DWORD ContextSwitchCount;
      DWORD64 WaitReasonBitMap;
      DWORD64 CycleTime;
      DWORD RetryCount;
      DWORD Reserved;
      HARDWARE_COUNTER_DATA HwCounters[MAX_HW_COUNTERS];
    } PERFORMANCE_DATA,*PPERFORMANCE_DATA;

#define PERFORMANCE_DATA_VERSION 1

#define READ_THREAD_PROFILING_FLAG_DISPATCHING 0x00000001
#define READ_THREAD_PROFILING_FLAG_HARDWARE_COUNTERS 0x00000002

#define DLL_PROCESS_ATTACH 1
#define DLL_THREAD_ATTACH 2
#define DLL_THREAD_DETACH 3
#define DLL_PROCESS_DETACH 0
#define DLL_PROCESS_VERIFIER 4

#define EVENTLOG_SEQUENTIAL_READ 0x0001
#define EVENTLOG_SEEK_READ 0x0002
#define EVENTLOG_FORWARDS_READ 0x0004
#define EVENTLOG_BACKWARDS_READ 0x0008

#define EVENTLOG_SUCCESS 0x0000
#define EVENTLOG_ERROR_TYPE 0x0001
#define EVENTLOG_WARNING_TYPE 0x0002
#define EVENTLOG_INFORMATION_TYPE 0x0004
#define EVENTLOG_AUDIT_SUCCESS 0x0008
#define EVENTLOG_AUDIT_FAILURE 0x0010

#define EVENTLOG_START_PAIRED_EVENT 0x0001
#define EVENTLOG_END_PAIRED_EVENT 0x0002
#define EVENTLOG_END_ALL_PAIRED_EVENTS 0x0004
#define EVENTLOG_PAIRED_EVENT_ACTIVE 0x0008
#define EVENTLOG_PAIRED_EVENT_INACTIVE 0x0010

    typedef struct _EVENTLOGRECORD {
      DWORD Length;
      DWORD Reserved;
      DWORD RecordNumber;
      DWORD TimeGenerated;
      DWORD TimeWritten;
      DWORD EventID;
      WORD EventType;
      WORD NumStrings;
      WORD EventCategory;
      WORD ReservedFlags;
      DWORD ClosingRecordNumber;
      DWORD StringOffset;
      DWORD UserSidLength;
      DWORD UserSidOffset;
      DWORD DataLength;
      DWORD DataOffset;
    } EVENTLOGRECORD,*PEVENTLOGRECORD;

#define MAXLOGICALLOGNAMESIZE 256

    typedef struct _EVENTSFORLOGFILE {
      DWORD ulSize;
      WCHAR szLogicalLogFile[MAXLOGICALLOGNAMESIZE];
      DWORD ulNumRecords;
      EVENTLOGRECORD pEventLogRecords[];
    } EVENTSFORLOGFILE,*PEVENTSFORLOGFILE;

    typedef struct _PACKEDEVENTINFO {
      DWORD ulSize;
      DWORD ulNumEventsForLogFile;
      DWORD ulOffsets[];
    } PACKEDEVENTINFO,*PPACKEDEVENTINFO;

#define KEY_QUERY_VALUE (0x0001)
#define KEY_SET_VALUE (0x0002)
#define KEY_CREATE_SUB_KEY (0x0004)
#define KEY_ENUMERATE_SUB_KEYS (0x0008)
#define KEY_NOTIFY (0x0010)
#define KEY_CREATE_LINK (0x0020)
#define KEY_WOW64_64KEY (0x0100)
#define KEY_WOW64_32KEY (0x0200)
#define KEY_WOW64_RES (0x0300)

#define KEY_READ ((STANDARD_RIGHTS_READ | KEY_QUERY_VALUE | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY) & (~SYNCHRONIZE))
#define KEY_WRITE ((STANDARD_RIGHTS_WRITE | KEY_SET_VALUE | KEY_CREATE_SUB_KEY) & (~SYNCHRONIZE))
#define KEY_EXECUTE ((KEY_READ) & (~SYNCHRONIZE))
#define KEY_ALL_ACCESS ((STANDARD_RIGHTS_ALL | KEY_QUERY_VALUE | KEY_SET_VALUE | KEY_CREATE_SUB_KEY | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY | KEY_CREATE_LINK) & (~SYNCHRONIZE))
#define REG_OPTION_RESERVED (__MSABI_LONG(0x00000000))

#define REG_OPTION_NON_VOLATILE (__MSABI_LONG(0x00000000))
#define REG_OPTION_VOLATILE (__MSABI_LONG(0x00000001))
#define REG_OPTION_CREATE_LINK (__MSABI_LONG(0x00000002))
#define REG_OPTION_BACKUP_RESTORE (__MSABI_LONG(0x00000004))
#define REG_OPTION_OPEN_LINK (__MSABI_LONG(0x00000008))
#define REG_LEGAL_OPTION (REG_OPTION_RESERVED | REG_OPTION_NON_VOLATILE | REG_OPTION_VOLATILE | REG_OPTION_CREATE_LINK | REG_OPTION_BACKUP_RESTORE | REG_OPTION_OPEN_LINK)

#define REG_CREATED_NEW_KEY (__MSABI_LONG(0x00000001))
#define REG_OPENED_EXISTING_KEY (__MSABI_LONG(0x00000002))

#define REG_STANDARD_FORMAT 1
#define REG_LATEST_FORMAT 2
#define REG_NO_COMPRESSION 4

#define REG_WHOLE_HIVE_VOLATILE (__MSABI_LONG(0x00000001))
#define REG_REFRESH_HIVE (__MSABI_LONG(0x00000002))
#define REG_NO_LAZY_FLUSH (__MSABI_LONG(0x00000004))
#define REG_FORCE_RESTORE (__MSABI_LONG(0x00000008))
#define REG_APP_HIVE (__MSABI_LONG(0x00000010))
#define REG_PROCESS_PRIVATE (__MSABI_LONG(0x00000020))
#define REG_START_JOURNAL (__MSABI_LONG(0x00000040))
#define REG_HIVE_EXACT_FILE_GROWTH (__MSABI_LONG(0x00000080))
#define REG_HIVE_NO_RM (__MSABI_LONG(0x00000100))
#define REG_HIVE_SINGLE_LOG (__MSABI_LONG(0x00000200))
#define REG_BOOT_HIVE (__MSABI_LONG(0x00000400))

#define REG_FORCE_UNLOAD 1

#define REG_NOTIFY_CHANGE_NAME (__MSABI_LONG(0x00000001))
#define REG_NOTIFY_CHANGE_ATTRIBUTES (__MSABI_LONG(0x00000002))
#define REG_NOTIFY_CHANGE_LAST_SET (__MSABI_LONG(0x00000004))
#define REG_NOTIFY_CHANGE_SECURITY (__MSABI_LONG(0x00000008))
#define REG_NOTIFY_THREAD_AGNOSTIC (__MSABI_LONG(0x10000000))

#define REG_LEGAL_CHANGE_FILTER (REG_NOTIFY_CHANGE_NAME | REG_NOTIFY_CHANGE_ATTRIBUTES | REG_NOTIFY_CHANGE_LAST_SET | REG_NOTIFY_CHANGE_SECURITY | REG_NOTIFY_THREAD_AGNOSTIC)

#define REG_NONE (0)
#define REG_SZ (1)
#define REG_EXPAND_SZ (2)
#define REG_BINARY (3)
#define REG_DWORD (4)
#define REG_DWORD_LITTLE_ENDIAN (4)
#define REG_DWORD_BIG_ENDIAN (5)
#define REG_LINK (6)
#define REG_MULTI_SZ (7)
#define REG_RESOURCE_LIST (8)
#define REG_FULL_RESOURCE_DESCRIPTOR (9)
#define REG_RESOURCE_REQUIREMENTS_LIST (10)
#define REG_QWORD (11)
#define REG_QWORD_LITTLE_ENDIAN (11)

#define SERVICE_KERNEL_DRIVER 0x00000001
#define SERVICE_FILE_SYSTEM_DRIVER 0x00000002
#define SERVICE_ADAPTER 0x00000004
#define SERVICE_RECOGNIZER_DRIVER 0x00000008

#define SERVICE_DRIVER (SERVICE_KERNEL_DRIVER | SERVICE_FILE_SYSTEM_DRIVER | SERVICE_RECOGNIZER_DRIVER)

#define SERVICE_WIN32_OWN_PROCESS 0x00000010
#define SERVICE_WIN32_SHARE_PROCESS 0x00000020
#define SERVICE_WIN32 (SERVICE_WIN32_OWN_PROCESS | SERVICE_WIN32_SHARE_PROCESS)

#define SERVICE_INTERACTIVE_PROCESS 0x00000100

#define SERVICE_TYPE_ALL (SERVICE_WIN32 | SERVICE_ADAPTER | SERVICE_DRIVER | SERVICE_INTERACTIVE_PROCESS)

#define SERVICE_BOOT_START 0x00000000
#define SERVICE_SYSTEM_START 0x00000001
#define SERVICE_AUTO_START 0x00000002
#define SERVICE_DEMAND_START 0x00000003
#define SERVICE_DISABLED 0x00000004

#define SERVICE_ERROR_IGNORE 0x00000000
#define SERVICE_ERROR_NORMAL 0x00000001
#define SERVICE_ERROR_SEVERE 0x00000002
#define SERVICE_ERROR_CRITICAL 0x00000003

    typedef enum _CM_SERVICE_NODE_TYPE {
      DriverType = SERVICE_KERNEL_DRIVER,FileSystemType = SERVICE_FILE_SYSTEM_DRIVER,Win32ServiceOwnProcess = SERVICE_WIN32_OWN_PROCESS,
      Win32ServiceShareProcess = SERVICE_WIN32_SHARE_PROCESS,AdapterType = SERVICE_ADAPTER,RecognizerType = SERVICE_RECOGNIZER_DRIVER
    } SERVICE_NODE_TYPE;

    typedef enum _CM_SERVICE_LOAD_TYPE {
      BootLoad = SERVICE_BOOT_START,SystemLoad = SERVICE_SYSTEM_START,AutoLoad = SERVICE_AUTO_START,DemandLoad = SERVICE_DEMAND_START,
      DisableLoad = SERVICE_DISABLED
    } SERVICE_LOAD_TYPE;

    typedef enum _CM_ERROR_CONTROL_TYPE {
      IgnoreError = SERVICE_ERROR_IGNORE,NormalError = SERVICE_ERROR_NORMAL,SevereError = SERVICE_ERROR_SEVERE,CriticalError = SERVICE_ERROR_CRITICAL
    } SERVICE_ERROR_TYPE;

#define CM_SERVICE_NETWORK_BOOT_LOAD 0x00000001
#define CM_SERVICE_VIRTUAL_DISK_BOOT_LOAD 0x00000002
#define CM_SERVICE_USB_DISK_BOOT_LOAD 0x00000004
#define CM_SERVICE_SD_DISK_BOOT_LOAD 0x00000008
#define CM_SERVICE_USB3_DISK_BOOT_LOAD 0x00000010
#define CM_SERVICE_MEASURED_BOOT_LOAD 0x00000020
#define CM_SERVICE_VERIFIER_BOOT_LOAD 0x00000040
#define CM_SERVICE_WINPE_BOOT_LOAD 0x00000080

#define CM_SERVICE_VALID_PROMOTION_MASK (CM_SERVICE_NETWORK_BOOT_LOAD | CM_SERVICE_VIRTUAL_DISK_BOOT_LOAD | CM_SERVICE_USB_DISK_BOOT_LOAD | CM_SERVICE_SD_DISK_BOOT_LOAD | CM_SERVICE_USB3_DISK_BOOT_LOAD | CM_SERVICE_MEASURED_BOOT_LOAD | CM_SERVICE_VERIFIER_BOOT_LOAD | CM_SERVICE_WINPE_BOOT_LOAD)

#ifndef _NTDDTAPE_WINNT_
#define _NTDDTAPE_WINNT_

#define TAPE_ERASE_SHORT __MSABI_LONG(0)
#define TAPE_ERASE_LONG __MSABI_LONG(1)

    typedef struct _TAPE_ERASE {
      DWORD Type;
      BOOLEAN Immediate;
    } TAPE_ERASE,*PTAPE_ERASE;

#define TAPE_LOAD __MSABI_LONG(0)
#define TAPE_UNLOAD __MSABI_LONG(1)
#define TAPE_TENSION __MSABI_LONG(2)
#define TAPE_LOCK __MSABI_LONG(3)
#define TAPE_UNLOCK __MSABI_LONG(4)
#define TAPE_FORMAT __MSABI_LONG(5)

    typedef struct _TAPE_PREPARE {
      DWORD Operation;
      BOOLEAN Immediate;
    } TAPE_PREPARE,*PTAPE_PREPARE;

#define TAPE_SETMARKS __MSABI_LONG(0)
#define TAPE_FILEMARKS __MSABI_LONG(1)
#define TAPE_SHORT_FILEMARKS __MSABI_LONG(2)
#define TAPE_LONG_FILEMARKS __MSABI_LONG(3)

    typedef struct _TAPE_WRITE_MARKS {
      DWORD Type;
      DWORD Count;
      BOOLEAN Immediate;
    } TAPE_WRITE_MARKS,*PTAPE_WRITE_MARKS;

#define TAPE_ABSOLUTE_POSITION __MSABI_LONG(0)
#define TAPE_LOGICAL_POSITION __MSABI_LONG(1)
#define TAPE_PSEUDO_LOGICAL_POSITION __MSABI_LONG(2)

    typedef struct _TAPE_GET_POSITION {
      DWORD Type;
      DWORD Partition;
      LARGE_INTEGER Offset;
    } TAPE_GET_POSITION,*PTAPE_GET_POSITION;

#define TAPE_REWIND __MSABI_LONG(0)
#define TAPE_ABSOLUTE_BLOCK __MSABI_LONG(1)
#define TAPE_LOGICAL_BLOCK __MSABI_LONG(2)
#define TAPE_PSEUDO_LOGICAL_BLOCK __MSABI_LONG(3)
#define TAPE_SPACE_END_OF_DATA __MSABI_LONG(4)
#define TAPE_SPACE_RELATIVE_BLOCKS __MSABI_LONG(5)
#define TAPE_SPACE_FILEMARKS __MSABI_LONG(6)
#define TAPE_SPACE_SEQUENTIAL_FMKS __MSABI_LONG(7)
#define TAPE_SPACE_SETMARKS __MSABI_LONG(8)
#define TAPE_SPACE_SEQUENTIAL_SMKS __MSABI_LONG(9)

    typedef struct _TAPE_SET_POSITION {
      DWORD Method;
      DWORD Partition;
      LARGE_INTEGER Offset;
      BOOLEAN Immediate;
    } TAPE_SET_POSITION,*PTAPE_SET_POSITION;

#define TAPE_DRIVE_FIXED 0x00000001
#define TAPE_DRIVE_SELECT 0x00000002
#define TAPE_DRIVE_INITIATOR 0x00000004

#define TAPE_DRIVE_ERASE_SHORT 0x00000010
#define TAPE_DRIVE_ERASE_LONG 0x00000020
#define TAPE_DRIVE_ERASE_BOP_ONLY 0x00000040
#define TAPE_DRIVE_ERASE_IMMEDIATE 0x00000080
#define TAPE_DRIVE_TAPE_CAPACITY 0x00000100
#define TAPE_DRIVE_TAPE_REMAINING 0x00000200
#define TAPE_DRIVE_FIXED_BLOCK 0x00000400
#define TAPE_DRIVE_VARIABLE_BLOCK 0x00000800
#define TAPE_DRIVE_WRITE_PROTECT 0x00001000
#define TAPE_DRIVE_EOT_WZ_SIZE 0x00002000
#define TAPE_DRIVE_ECC 0x00010000
#define TAPE_DRIVE_COMPRESSION 0x00020000
#define TAPE_DRIVE_PADDING 0x00040000
#define TAPE_DRIVE_REPORT_SMKS 0x00080000
#define TAPE_DRIVE_GET_ABSOLUTE_BLK 0x00100000
#define TAPE_DRIVE_GET_LOGICAL_BLK 0x00200000
#define TAPE_DRIVE_SET_EOT_WZ_SIZE 0x00400000
#define TAPE_DRIVE_EJECT_MEDIA 0x01000000
#define TAPE_DRIVE_CLEAN_REQUESTS 0x02000000
#define TAPE_DRIVE_SET_CMP_BOP_ONLY 0x04000000

#define TAPE_DRIVE_RESERVED_BIT 0x80000000

#define TAPE_DRIVE_LOAD_UNLOAD 0x80000001
#define TAPE_DRIVE_TENSION 0x80000002
#define TAPE_DRIVE_LOCK_UNLOCK 0x80000004
#define TAPE_DRIVE_REWIND_IMMEDIATE 0x80000008
#define TAPE_DRIVE_SET_BLOCK_SIZE 0x80000010

#define TAPE_DRIVE_LOAD_UNLD_IMMED 0x80000020
#define TAPE_DRIVE_TENSION_IMMED 0x80000040
#define TAPE_DRIVE_LOCK_UNLK_IMMED 0x80000080

#define TAPE_DRIVE_SET_ECC 0x80000100
#define TAPE_DRIVE_SET_COMPRESSION 0x80000200
#define TAPE_DRIVE_SET_PADDING 0x80000400
#define TAPE_DRIVE_SET_REPORT_SMKS 0x80000800

#define TAPE_DRIVE_ABSOLUTE_BLK 0x80001000
#define TAPE_DRIVE_ABS_BLK_IMMED 0x80002000
#define TAPE_DRIVE_LOGICAL_BLK 0x80004000
#define TAPE_DRIVE_LOG_BLK_IMMED 0x80008000

#define TAPE_DRIVE_END_OF_DATA 0x80010000
#define TAPE_DRIVE_RELATIVE_BLKS 0x80020000
#define TAPE_DRIVE_FILEMARKS 0x80040000
#define TAPE_DRIVE_SEQUENTIAL_FMKS 0x80080000

#define TAPE_DRIVE_SETMARKS 0x80100000
#define TAPE_DRIVE_SEQUENTIAL_SMKS 0x80200000
#define TAPE_DRIVE_REVERSE_POSITION 0x80400000
#define TAPE_DRIVE_SPACE_IMMEDIATE 0x80800000

#define TAPE_DRIVE_WRITE_SETMARKS 0x81000000
#define TAPE_DRIVE_WRITE_FILEMARKS 0x82000000
#define TAPE_DRIVE_WRITE_SHORT_FMKS 0x84000000
#define TAPE_DRIVE_WRITE_LONG_FMKS 0x88000000

#define TAPE_DRIVE_WRITE_MARK_IMMED 0x90000000
#define TAPE_DRIVE_FORMAT 0xA0000000
#define TAPE_DRIVE_FORMAT_IMMEDIATE 0xC0000000
#define TAPE_DRIVE_HIGH_FEATURES 0x80000000

    typedef struct _TAPE_GET_DRIVE_PARAMETERS {
      BOOLEAN ECC;
      BOOLEAN Compression;
      BOOLEAN DataPadding;
      BOOLEAN ReportSetmarks;
      DWORD DefaultBlockSize;
      DWORD MaximumBlockSize;
      DWORD MinimumBlockSize;
      DWORD MaximumPartitionCount;
      DWORD FeaturesLow;
      DWORD FeaturesHigh;
      DWORD EOTWarningZoneSize;
    } TAPE_GET_DRIVE_PARAMETERS,*PTAPE_GET_DRIVE_PARAMETERS;

    typedef struct _TAPE_SET_DRIVE_PARAMETERS {
      BOOLEAN ECC;
      BOOLEAN Compression;
      BOOLEAN DataPadding;
      BOOLEAN ReportSetmarks;
      DWORD EOTWarningZoneSize;
    } TAPE_SET_DRIVE_PARAMETERS,*PTAPE_SET_DRIVE_PARAMETERS;

    typedef struct _TAPE_GET_MEDIA_PARAMETERS {
      LARGE_INTEGER Capacity;
      LARGE_INTEGER Remaining;
      DWORD BlockSize;
      DWORD PartitionCount;
      BOOLEAN WriteProtected;
    } TAPE_GET_MEDIA_PARAMETERS,*PTAPE_GET_MEDIA_PARAMETERS;

    typedef struct _TAPE_SET_MEDIA_PARAMETERS {
      DWORD BlockSize;
    } TAPE_SET_MEDIA_PARAMETERS,*PTAPE_SET_MEDIA_PARAMETERS;

#define TAPE_FIXED_PARTITIONS __MSABI_LONG(0)
#define TAPE_SELECT_PARTITIONS __MSABI_LONG(1)
#define TAPE_INITIATOR_PARTITIONS __MSABI_LONG(2)

    typedef struct _TAPE_CREATE_PARTITION {
      DWORD Method;
      DWORD Count;
      DWORD Size;
    } TAPE_CREATE_PARTITION,*PTAPE_CREATE_PARTITION;

#define TAPE_QUERY_DRIVE_PARAMETERS __MSABI_LONG(0)
#define TAPE_QUERY_MEDIA_CAPACITY __MSABI_LONG(1)
#define TAPE_CHECK_FOR_DRIVE_PROBLEM __MSABI_LONG(2)
#define TAPE_QUERY_IO_ERROR_DATA __MSABI_LONG(3)
#define TAPE_QUERY_DEVICE_ERROR_DATA __MSABI_LONG(4)

    typedef struct _TAPE_WMI_OPERATIONS {
      DWORD Method;
      DWORD DataBufferSize;
      PVOID DataBuffer;
    } TAPE_WMI_OPERATIONS,*PTAPE_WMI_OPERATIONS;

    typedef enum _TAPE_DRIVE_PROBLEM_TYPE {
      TapeDriveProblemNone,TapeDriveReadWriteWarning,TapeDriveReadWriteError,TapeDriveReadWarning,TapeDriveWriteWarning,TapeDriveReadError,TapeDriveWriteError,TapeDriveHardwareError,TapeDriveUnsupportedMedia,TapeDriveScsiConnectionError,TapeDriveTimetoClean,TapeDriveCleanDriveNow,TapeDriveMediaLifeExpired,TapeDriveSnappedTape
    } TAPE_DRIVE_PROBLEM_TYPE;
#endif

  typedef DWORD TP_VERSION,*PTP_VERSION;
  typedef struct _TP_CALLBACK_INSTANCE TP_CALLBACK_INSTANCE,*PTP_CALLBACK_INSTANCE;
  typedef VOID (NTAPI *PTP_SIMPLE_CALLBACK) (PTP_CALLBACK_INSTANCE Instance, PVOID Context);
  typedef struct _TP_POOL TP_POOL,*PTP_POOL;

  typedef enum _TP_CALLBACK_PRIORITY {
    TP_CALLBACK_PRIORITY_HIGH,
    TP_CALLBACK_PRIORITY_NORMAL,
    TP_CALLBACK_PRIORITY_LOW,
    TP_CALLBACK_PRIORITY_INVALID,
    TP_CALLBACK_PRIORITY_COUNT = TP_CALLBACK_PRIORITY_INVALID
  } TP_CALLBACK_PRIORITY;

  typedef struct _TP_POOL_STACK_INFORMATION {
    SIZE_T StackReserve;
    SIZE_T StackCommit;
  } TP_POOL_STACK_INFORMATION, *PTP_POOL_STACK_INFORMATION;

  typedef struct _TP_CLEANUP_GROUP TP_CLEANUP_GROUP,*PTP_CLEANUP_GROUP;
  typedef VOID (NTAPI *PTP_CLEANUP_GROUP_CANCEL_CALLBACK) (PVOID ObjectContext, PVOID CleanupContext);

#if _WIN32_WINNT >= 0x0601
  typedef struct _TP_CALLBACK_ENVIRON_V3 {
    TP_VERSION Version;
    PTP_POOL Pool;
    PTP_CLEANUP_GROUP CleanupGroup;
    PTP_CLEANUP_GROUP_CANCEL_CALLBACK CleanupGroupCancelCallback;
    PVOID RaceDll;
    struct _ACTIVATION_CONTEXT *ActivationContext;
    PTP_SIMPLE_CALLBACK FinalizationCallback;
    union {
      DWORD Flags;
      struct {
        DWORD LongFunction : 1;
        DWORD Persistent : 1;
        DWORD Private : 30;
      } s;
    } u;
    TP_CALLBACK_PRIORITY CallbackPriority;
    DWORD Size;
  } TP_CALLBACK_ENVIRON_V3;
  typedef TP_CALLBACK_ENVIRON_V3 TP_CALLBACK_ENVIRON, *PTP_CALLBACK_ENVIRON;
#else
  typedef struct _TP_CALLBACK_ENVIRON_V1 {
    TP_VERSION Version;
    PTP_POOL Pool;
    PTP_CLEANUP_GROUP CleanupGroup;
    PTP_CLEANUP_GROUP_CANCEL_CALLBACK CleanupGroupCancelCallback;
    PVOID RaceDll;
    struct _ACTIVATION_CONTEXT *ActivationContext;
    PTP_SIMPLE_CALLBACK FinalizationCallback;
    union {
      DWORD Flags;
      struct {
	DWORD LongFunction : 1;
	DWORD Persistent : 1;
	DWORD Private : 30;
      } s;
    } u;
  } TP_CALLBACK_ENVIRON_V1;
  typedef TP_CALLBACK_ENVIRON_V1 TP_CALLBACK_ENVIRON,*PTP_CALLBACK_ENVIRON;
#endif

  typedef struct _TP_WORK TP_WORK,*PTP_WORK;
  typedef VOID (NTAPI *PTP_WORK_CALLBACK) (PTP_CALLBACK_INSTANCE Instance, PVOID Context, PTP_WORK Work);
  typedef struct _TP_TIMER TP_TIMER,*PTP_TIMER;
  typedef VOID (NTAPI *PTP_TIMER_CALLBACK) (PTP_CALLBACK_INSTANCE Instance, PVOID Context, PTP_TIMER Timer);
  typedef DWORD TP_WAIT_RESULT;
  typedef struct _TP_WAIT TP_WAIT,*PTP_WAIT;
  typedef VOID (NTAPI *PTP_WAIT_CALLBACK) (PTP_CALLBACK_INSTANCE Instance, PVOID Context, PTP_WAIT Wait, TP_WAIT_RESULT WaitResult);
  typedef struct _TP_IO TP_IO,*PTP_IO;

#if !defined (__WIDL__)
    FORCEINLINE VOID TpInitializeCallbackEnviron (PTP_CALLBACK_ENVIRON cbe) {
      cbe->Pool = NULL;
      cbe->CleanupGroup = NULL;
      cbe->CleanupGroupCancelCallback = NULL;
      cbe->RaceDll = NULL;
      cbe->ActivationContext = NULL;
      cbe->FinalizationCallback = NULL;
      cbe->u.Flags = 0;
#if _WIN32_WINNT < 0x0601
      cbe->Version = 1;
#else
      cbe->Version = 3;
      cbe->CallbackPriority = TP_CALLBACK_PRIORITY_NORMAL;
      cbe->Size = sizeof (TP_CALLBACK_ENVIRON);
#endif
    }
    FORCEINLINE VOID TpSetCallbackThreadpool (PTP_CALLBACK_ENVIRON cbe, PTP_POOL pool) { cbe->Pool = pool; }
    FORCEINLINE VOID TpSetCallbackCleanupGroup (PTP_CALLBACK_ENVIRON cbe, PTP_CLEANUP_GROUP cleanup_group, PTP_CLEANUP_GROUP_CANCEL_CALLBACK cleanup_group_cb) {
      cbe->CleanupGroup = cleanup_group;
      cbe->CleanupGroupCancelCallback = cleanup_group_cb;
    }
    FORCEINLINE VOID TpSetCallbackActivationContext (PTP_CALLBACK_ENVIRON cbe, struct _ACTIVATION_CONTEXT *actx) { cbe->ActivationContext = actx; }
    FORCEINLINE VOID TpSetCallbackNoActivationContext (PTP_CALLBACK_ENVIRON cbe) { cbe->ActivationContext = (struct _ACTIVATION_CONTEXT *) (LONG_PTR) -1; }
    FORCEINLINE VOID TpSetCallbackLongFunction (PTP_CALLBACK_ENVIRON cbe) { cbe->u.s.LongFunction = 1; }
    FORCEINLINE VOID TpSetCallbackRaceWithDll (PTP_CALLBACK_ENVIRON cbe, PVOID h) { cbe->RaceDll = h; }
    FORCEINLINE VOID TpSetCallbackFinalizationCallback (PTP_CALLBACK_ENVIRON cbe, PTP_SIMPLE_CALLBACK fini_cb) { cbe->FinalizationCallback = fini_cb; }
#if _WIN32_WINNT >= 0x0601
    FORCEINLINE VOID TpSetCallbackPriority (PTP_CALLBACK_ENVIRON cbe, TP_CALLBACK_PRIORITY prio) { cbe->CallbackPriority = prio; }
#endif
    FORCEINLINE VOID TpSetCallbackPersistent (PTP_CALLBACK_ENVIRON cbe) { cbe->u.s.Persistent = 1; }
    FORCEINLINE VOID TpDestroyCallbackEnviron (PTP_CALLBACK_ENVIRON cbe) { UNREFERENCED_PARAMETER (cbe); }
#endif

#if defined(__x86_64) && !defined (__WIDL__)
    struct _TEB *NtCurrentTeb(VOID);
    PVOID GetCurrentFiber(VOID);
    PVOID GetFiberData(VOID);
    FORCEINLINE struct _TEB *NtCurrentTeb(VOID) { return (struct _TEB *)__readgsqword(FIELD_OFFSET(NT_TIB,Self)); }
    FORCEINLINE PVOID GetCurrentFiber(VOID) { return(PVOID)__readgsqword(FIELD_OFFSET(NT_TIB,FiberData)); }
    FORCEINLINE PVOID GetFiberData(VOID) {
      return *(PVOID *)GetCurrentFiber();
    }
#endif /* __x86_64 */

#if defined (__arm__) && !defined (__WIDL__)
    struct _TEB *NtCurrentTeb (VOID);
    PVOID GetCurrentFiber (VOID);
    PVOID GetFiberData (VOID);
    FORCEINLINE struct _TEB *NtCurrentTeb(VOID) { struct _TEB *teb;
    __asm ("mrc p15, 0, %0, c13, c0, 2" : "=r" (teb));
    return teb; }
    FORCEINLINE PVOID GetCurrentFiber(VOID) { return (PVOID)(((PNT_TIB)NtCurrentTeb())->FiberData); }
    FORCEINLINE PVOID GetFiberData (VOID) { return *(PVOID *)GetCurrentFiber (); }
#endif /* arm */

#if defined (__aarch64__) && !defined (__WIDL__)
    struct _TEB *NtCurrentTeb (VOID);
    PVOID GetCurrentFiber (VOID);
    PVOID GetFiberData (VOID);
    FORCEINLINE struct _TEB *NtCurrentTeb(VOID) { struct _TEB *teb;
    __asm ("mov %0, x18" : "=r" (teb));
    return teb; }
    FORCEINLINE PVOID GetCurrentFiber(VOID) { return (PVOID)(((PNT_TIB)NtCurrentTeb())->FiberData); }
    FORCEINLINE PVOID GetFiberData (VOID) { return *(PVOID *)GetCurrentFiber (); }
#endif /* aarch64 */

#ifndef _NTTMAPI_
#define _NTTMAPI_

#ifdef __cplusplus
    extern "C" {
#endif

#include <ktmtypes.h>

#define TRANSACTIONMANAGER_QUERY_INFORMATION 0x00001
#define TRANSACTIONMANAGER_SET_INFORMATION 0x00002
#define TRANSACTIONMANAGER_RECOVER 0x00004
#define TRANSACTIONMANAGER_RENAME 0x00008
#define TRANSACTIONMANAGER_CREATE_RM 0x00010
#define TRANSACTIONMANAGER_BIND_TRANSACTION 0x00020

#define TRANSACTIONMANAGER_GENERIC_READ (STANDARD_RIGHTS_READ | TRANSACTIONMANAGER_QUERY_INFORMATION)
#define TRANSACTIONMANAGER_GENERIC_WRITE (STANDARD_RIGHTS_WRITE | TRANSACTIONMANAGER_SET_INFORMATION | TRANSACTIONMANAGER_RECOVER | TRANSACTIONMANAGER_RENAME | TRANSACTIONMANAGER_CREATE_RM)
#define TRANSACTIONMANAGER_GENERIC_EXECUTE (STANDARD_RIGHTS_EXECUTE)
#define TRANSACTIONMANAGER_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED | TRANSACTIONMANAGER_GENERIC_READ | TRANSACTIONMANAGER_GENERIC_WRITE | TRANSACTIONMANAGER_GENERIC_EXECUTE | TRANSACTIONMANAGER_BIND_TRANSACTION)

#define TRANSACTION_QUERY_INFORMATION (0x0001)
#define TRANSACTION_SET_INFORMATION (0x0002)
#define TRANSACTION_ENLIST (0x0004)
#define TRANSACTION_COMMIT (0x0008)
#define TRANSACTION_ROLLBACK (0x0010)
#define TRANSACTION_PROPAGATE (0x0020)
#define TRANSACTION_RIGHT_RESERVED1 (0x0040)

#define TRANSACTION_GENERIC_READ (STANDARD_RIGHTS_READ | TRANSACTION_QUERY_INFORMATION | SYNCHRONIZE)
#define TRANSACTION_GENERIC_WRITE (STANDARD_RIGHTS_WRITE | TRANSACTION_SET_INFORMATION | TRANSACTION_COMMIT | TRANSACTION_ENLIST | TRANSACTION_ROLLBACK | TRANSACTION_PROPAGATE | SYNCHRONIZE)
#define TRANSACTION_GENERIC_EXECUTE (STANDARD_RIGHTS_EXECUTE | TRANSACTION_COMMIT | TRANSACTION_ROLLBACK | SYNCHRONIZE)
#define TRANSACTION_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED | TRANSACTION_GENERIC_READ | TRANSACTION_GENERIC_WRITE | TRANSACTION_GENERIC_EXECUTE)
#define TRANSACTION_RESOURCE_MANAGER_RIGHTS (TRANSACTION_GENERIC_READ | STANDARD_RIGHTS_WRITE | TRANSACTION_SET_INFORMATION | TRANSACTION_ENLIST | TRANSACTION_ROLLBACK | TRANSACTION_PROPAGATE | SYNCHRONIZE)

#define RESOURCEMANAGER_QUERY_INFORMATION (0x0001)
#define RESOURCEMANAGER_SET_INFORMATION (0x0002)
#define RESOURCEMANAGER_RECOVER (0x0004)
#define RESOURCEMANAGER_ENLIST (0x0008)
#define RESOURCEMANAGER_GET_NOTIFICATION (0x0010)
#define RESOURCEMANAGER_REGISTER_PROTOCOL (0x0020)
#define RESOURCEMANAGER_COMPLETE_PROPAGATION (0x0040)

#define RESOURCEMANAGER_GENERIC_READ (STANDARD_RIGHTS_READ | RESOURCEMANAGER_QUERY_INFORMATION | SYNCHRONIZE)
#define RESOURCEMANAGER_GENERIC_WRITE (STANDARD_RIGHTS_WRITE | RESOURCEMANAGER_SET_INFORMATION | RESOURCEMANAGER_RECOVER | RESOURCEMANAGER_ENLIST | RESOURCEMANAGER_GET_NOTIFICATION | RESOURCEMANAGER_REGISTER_PROTOCOL | RESOURCEMANAGER_COMPLETE_PROPAGATION | SYNCHRONIZE)
#define RESOURCEMANAGER_GENERIC_EXECUTE (STANDARD_RIGHTS_EXECUTE | RESOURCEMANAGER_RECOVER | RESOURCEMANAGER_ENLIST | RESOURCEMANAGER_GET_NOTIFICATION | RESOURCEMANAGER_COMPLETE_PROPAGATION | SYNCHRONIZE)
#define RESOURCEMANAGER_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED | RESOURCEMANAGER_GENERIC_READ | RESOURCEMANAGER_GENERIC_WRITE | RESOURCEMANAGER_GENERIC_EXECUTE)

#define ENLISTMENT_QUERY_INFORMATION 1
#define ENLISTMENT_SET_INFORMATION 2
#define ENLISTMENT_RECOVER 4
#define ENLISTMENT_SUBORDINATE_RIGHTS 8
#define ENLISTMENT_SUPERIOR_RIGHTS 0x10

#define ENLISTMENT_GENERIC_READ (STANDARD_RIGHTS_READ | ENLISTMENT_QUERY_INFORMATION)
#define ENLISTMENT_GENERIC_WRITE (STANDARD_RIGHTS_WRITE | ENLISTMENT_SET_INFORMATION | ENLISTMENT_RECOVER | ENLISTMENT_SUBORDINATE_RIGHTS | ENLISTMENT_SUPERIOR_RIGHTS)
#define ENLISTMENT_GENERIC_EXECUTE (STANDARD_RIGHTS_EXECUTE | ENLISTMENT_RECOVER | ENLISTMENT_SUBORDINATE_RIGHTS | ENLISTMENT_SUPERIOR_RIGHTS)
#define ENLISTMENT_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED | ENLISTMENT_GENERIC_READ | ENLISTMENT_GENERIC_WRITE | ENLISTMENT_GENERIC_EXECUTE)

      typedef enum _TRANSACTION_OUTCOME {
	TransactionOutcomeUndetermined = 1,
	TransactionOutcomeCommitted,
	TransactionOutcomeAborted,
      } TRANSACTION_OUTCOME;

      typedef enum _TRANSACTION_STATE {
	TransactionStateNormal = 1,
	TransactionStateIndoubt,
	TransactionStateCommittedNotify,
      } TRANSACTION_STATE;

      typedef struct _TRANSACTION_BASIC_INFORMATION {
	GUID TransactionId;
	DWORD State;
	DWORD Outcome;
      } TRANSACTION_BASIC_INFORMATION,*PTRANSACTION_BASIC_INFORMATION;

      typedef struct _TRANSACTIONMANAGER_BASIC_INFORMATION {
	GUID TmIdentity;
	LARGE_INTEGER VirtualClock;
      } TRANSACTIONMANAGER_BASIC_INFORMATION,*PTRANSACTIONMANAGER_BASIC_INFORMATION;

      typedef struct _TRANSACTIONMANAGER_LOG_INFORMATION {
	GUID LogIdentity;
      } TRANSACTIONMANAGER_LOG_INFORMATION,*PTRANSACTIONMANAGER_LOG_INFORMATION;

      typedef struct _TRANSACTIONMANAGER_LOGPATH_INFORMATION {
	DWORD LogPathLength;
	WCHAR LogPath[1];
      } TRANSACTIONMANAGER_LOGPATH_INFORMATION,*PTRANSACTIONMANAGER_LOGPATH_INFORMATION;

      typedef struct _TRANSACTIONMANAGER_RECOVERY_INFORMATION {
	ULONGLONG LastRecoveredLsn;
      } TRANSACTIONMANAGER_RECOVERY_INFORMATION,*PTRANSACTIONMANAGER_RECOVERY_INFORMATION;

      typedef struct _TRANSACTIONMANAGER_OLDEST_INFORMATION {
	GUID OldestTransactionGuid;
      } TRANSACTIONMANAGER_OLDEST_INFORMATION,*PTRANSACTIONMANAGER_OLDEST_INFORMATION;

      typedef struct _TRANSACTION_PROPERTIES_INFORMATION {
	DWORD IsolationLevel;
	DWORD IsolationFlags;
	LARGE_INTEGER Timeout;
	DWORD Outcome;
	DWORD DescriptionLength;
	WCHAR Description[1];
      } TRANSACTION_PROPERTIES_INFORMATION,*PTRANSACTION_PROPERTIES_INFORMATION;

      typedef struct _TRANSACTION_BIND_INFORMATION {
	HANDLE TmHandle;
      } TRANSACTION_BIND_INFORMATION,*PTRANSACTION_BIND_INFORMATION;

      typedef struct _TRANSACTION_ENLISTMENT_PAIR {
	GUID EnlistmentId;
	GUID ResourceManagerId;
      } TRANSACTION_ENLISTMENT_PAIR,*PTRANSACTION_ENLISTMENT_PAIR;

      typedef struct _TRANSACTION_ENLISTMENTS_INFORMATION {
	DWORD NumberOfEnlistments;
	TRANSACTION_ENLISTMENT_PAIR EnlistmentPair[1];
      } TRANSACTION_ENLISTMENTS_INFORMATION,*PTRANSACTION_ENLISTMENTS_INFORMATION;

      typedef struct _TRANSACTION_SUPERIOR_ENLISTMENT_INFORMATION {
	TRANSACTION_ENLISTMENT_PAIR SuperiorEnlistmentPair;
      } TRANSACTION_SUPERIOR_ENLISTMENT_INFORMATION,*PTRANSACTION_SUPERIOR_ENLISTMENT_INFORMATION;

      typedef struct _RESOURCEMANAGER_BASIC_INFORMATION {
	GUID ResourceManagerId;
	DWORD DescriptionLength;
	WCHAR Description[1];
      } RESOURCEMANAGER_BASIC_INFORMATION,*PRESOURCEMANAGER_BASIC_INFORMATION;

      typedef struct _RESOURCEMANAGER_COMPLETION_INFORMATION {
	HANDLE IoCompletionPortHandle;
	ULONG_PTR CompletionKey;
      } RESOURCEMANAGER_COMPLETION_INFORMATION,*PRESOURCEMANAGER_COMPLETION_INFORMATION;

      typedef enum _TRANSACTION_INFORMATION_CLASS {
	TransactionBasicInformation,
	TransactionPropertiesInformation,
	TransactionEnlistmentInformation,
	TransactionSuperiorEnlistmentInformation,
	TransactionBindInformation,
	TransactionDTCPrivateInformation
      } TRANSACTION_INFORMATION_CLASS;

      typedef enum _TRANSACTIONMANAGER_INFORMATION_CLASS {
	TransactionManagerBasicInformation,
	TransactionManagerLogInformation,
	TransactionManagerLogPathInformation,
	TransactionManagerOnlineProbeInformation = 3,
	TransactionManagerRecoveryInformation = 4,
	TransactionManagerOldestTransactionInformation = 5
      } TRANSACTIONMANAGER_INFORMATION_CLASS;

      typedef enum _RESOURCEMANAGER_INFORMATION_CLASS {
	ResourceManagerBasicInformation,
	ResourceManagerCompletionInformation
      } RESOURCEMANAGER_INFORMATION_CLASS;

      typedef struct _ENLISTMENT_BASIC_INFORMATION {
	GUID EnlistmentId;
	GUID TransactionId;
	GUID ResourceManagerId;
      } ENLISTMENT_BASIC_INFORMATION,*PENLISTMENT_BASIC_INFORMATION;

      typedef struct _ENLISTMENT_CRM_INFORMATION {
	GUID CrmTransactionManagerId;
	GUID CrmResourceManagerId;
	GUID CrmEnlistmentId;
      } ENLISTMENT_CRM_INFORMATION,*PENLISTMENT_CRM_INFORMATION;

      typedef enum _ENLISTMENT_INFORMATION_CLASS {
	EnlistmentBasicInformation,
	EnlistmentRecoveryInformation,
	EnlistmentCrmInformation
      } ENLISTMENT_INFORMATION_CLASS;

      typedef struct _TRANSACTION_LIST_ENTRY {
	/*UOW*/ GUID UOW;
      } TRANSACTION_LIST_ENTRY,*PTRANSACTION_LIST_ENTRY;

      typedef struct _TRANSACTION_LIST_INFORMATION {
	DWORD NumberOfTransactions;
	TRANSACTION_LIST_ENTRY TransactionInformation[1];
      } TRANSACTION_LIST_INFORMATION,*PTRANSACTION_LIST_INFORMATION;

      typedef enum _KTMOBJECT_TYPE {
	KTMOBJECT_TRANSACTION,
	KTMOBJECT_TRANSACTION_MANAGER,
	KTMOBJECT_RESOURCE_MANAGER,
	KTMOBJECT_ENLISTMENT,
	KTMOBJECT_INVALID
      } KTMOBJECT_TYPE,*PKTMOBJECT_TYPE;

      typedef struct _KTMOBJECT_CURSOR {
	GUID LastQuery;
	DWORD ObjectIdCount;
	GUID ObjectIds[1];
      } KTMOBJECT_CURSOR,*PKTMOBJECT_CURSOR;

#ifdef __cplusplus
    }
#endif

#endif

/* Field Names From (See _fields_ section)
 * FIXME: Verify these against documentation
 * -- These documentation describes Win32 Constants and Structures in Python --
 * Constants - http://packages.python.org/winappdbg/winappdbg.win32.context_i386-pysrc.html
 * WOW64_FLOATING_SAVE_AREA - http://packages.python.org/winappdbg/winappdbg.win32.context_amd64.WOW64_FLOATING_SAVE_AREA-class.html
 * WOW64_CONTEXT - http://packages.python.org/winappdbg/winappdbg.win32.context_amd64.WOW64_CONTEXT-class.html
 */

#define WOW64_CONTEXT_i386 0x00010000
#define WOW64_CONTEXT_i486 0x00010000
#define WOW64_CONTEXT_CONTROL (WOW64_CONTEXT_i386 | __MSABI_LONG(0x00000001))
#define WOW64_CONTEXT_INTEGER (WOW64_CONTEXT_i386 | __MSABI_LONG(0x00000002))
#define WOW64_CONTEXT_SEGMENTS (WOW64_CONTEXT_i386 | __MSABI_LONG(0x00000004))
#define WOW64_CONTEXT_FLOATING_POINT (WOW64_CONTEXT_i386 | __MSABI_LONG(0x00000008))
#define WOW64_CONTEXT_DEBUG_REGISTERS (WOW64_CONTEXT_i386 | __MSABI_LONG(0x00000010))
#define WOW64_CONTEXT_EXTENDED_REGISTERS (WOW64_CONTEXT_i386 | __MSABI_LONG(0x00000020))
#define WOW64_CONTEXT_FULL (WOW64_CONTEXT_CONTROL | WOW64_CONTEXT_INTEGER | WOW64_CONTEXT_SEGMENTS)
#define WOW64_CONTEXT_ALL (WOW64_CONTEXT_CONTROL | WOW64_CONTEXT_INTEGER | WOW64_CONTEXT_SEGMENTS | WOW64_CONTEXT_FLOATING_POINT | WOW64_CONTEXT_DEBUG_REGISTERS | WOW64_CONTEXT_EXTENDED_REGISTERS)

#define WOW64_CONTEXT_XSTATE (WOW64_CONTEXT_i386 | __MSABI_LONG(0x00000040))

#define WOW64_CONTEXT_EXCEPTION_ACTIVE 0x08000000
#define WOW64_CONTEXT_SERVICE_ACTIVE 0x10000000
#define WOW64_CONTEXT_EXCEPTION_REQUEST 0x40000000
#define WOW64_CONTEXT_EXCEPTION_REPORTING 0x80000000

#define WOW64_SIZE_OF_80387_REGISTERS 80
#define WOW64_MAXIMUM_SUPPORTED_EXTENSION 512

typedef struct _WOW64_FLOATING_SAVE_AREA {
  DWORD   ControlWord;
  DWORD   StatusWord;
  DWORD   TagWord;
  DWORD   ErrorOffset;
  DWORD   ErrorSelector;
  DWORD   DataOffset;
  DWORD   DataSelector;
  BYTE    RegisterArea[WOW64_SIZE_OF_80387_REGISTERS];
  DWORD   Cr0NpxState;
} WOW64_FLOATING_SAVE_AREA, *PWOW64_FLOATING_SAVE_AREA;

#include "pshpack4.h"
typedef struct _WOW64_CONTEXT {
  DWORD ContextFlags;
  DWORD Dr0;
  DWORD Dr1;
  DWORD Dr2;
  DWORD Dr3;
  DWORD Dr6;
  DWORD Dr7;
  WOW64_FLOATING_SAVE_AREA FloatSave;
  DWORD SegGs;
  DWORD SegFs;
  DWORD SegEs;
  DWORD SegDs;
  DWORD Edi;
  DWORD Esi;
  DWORD Ebx;
  DWORD Edx;
  DWORD Ecx;
  DWORD Eax;
  DWORD Ebp;
  DWORD Eip;
  DWORD SegCs;
  DWORD EFlags;
  DWORD Esp;
  DWORD SegSs;
  BYTE ExtendedRegisters[WOW64_MAXIMUM_SUPPORTED_EXTENSION];
} WOW64_CONTEXT, *PWOW64_CONTEXT;
#include "poppack.h"

typedef struct _WOW64_LDT_ENTRY {
  WORD  LimitLow;
  WORD  BaseLow;
  __C89_NAMELESS union {
    struct {
      BYTE BaseMid;
      BYTE Flags1;
      BYTE Flags2;
      BYTE BaseHi;
    } Bytes;
    struct {
      DWORD BaseMid  :8;
      DWORD Type  :5;
      DWORD Dpl  :2;
      DWORD Pres  :1;
      DWORD LimitHi  :4;
      DWORD Sys  :1;
      DWORD Reserved_0  :1;
      DWORD Default_Big  :1;
      DWORD Granularity  :1;
      DWORD BaseHi  :8;
    } Bits;
  } HighWord;
} WOW64_LDT_ENTRY, *PWOW64_LDT_ENTRY;

    typedef struct _WOW64_DESCRIPTOR_TABLE_ENTRY {
      DWORD Selector;
      WOW64_LDT_ENTRY Descriptor;
    } WOW64_DESCRIPTOR_TABLE_ENTRY,*PWOW64_DESCRIPTOR_TABLE_ENTRY;

#if (_WIN32_WINNT >= 0x0601)

#ifndef ___PROCESSOR_NUMBER_DEFINED
#define ___PROCESSOR_NUMBER_DEFINED
typedef struct _PROCESSOR_NUMBER {
  WORD Group;
  BYTE Number;
  BYTE Reserved;
} PROCESSOR_NUMBER, *PPROCESSOR_NUMBER;

#define ALL_PROCESSOR_GROUPS 0xffff
#endif /* !___PROCESSOR_NUMBER_DEFINED */

#endif /*(_WIN32_WINNT >= 0x0601)*/

#define ACTIVATION_CONTEXT_SECTION_ASSEMBLY_INFORMATION (1)
#define ACTIVATION_CONTEXT_SECTION_DLL_REDIRECTION (2)
#define ACTIVATION_CONTEXT_SECTION_WINDOW_CLASS_REDIRECTION (3)
#define ACTIVATION_CONTEXT_SECTION_COM_SERVER_REDIRECTION (4)
#define ACTIVATION_CONTEXT_SECTION_COM_INTERFACE_REDIRECTION (5)
#define ACTIVATION_CONTEXT_SECTION_COM_TYPE_LIBRARY_REDIRECTION (6)
#define ACTIVATION_CONTEXT_SECTION_COM_PROGID_REDIRECTION (7)
#define ACTIVATION_CONTEXT_SECTION_GLOBAL_OBJECT_RENAME_TABLE (8)
#define ACTIVATION_CONTEXT_SECTION_CLR_SURROGATES (9)
#define ACTIVATION_CONTEXT_SECTION_APPLICATION_SETTINGS (10)
#define ACTIVATION_CONTEXT_SECTION_COMPATIBILITY_INFO (11)

#ifdef __cplusplus
}
#endif

#endif /* _WINNT_ */

