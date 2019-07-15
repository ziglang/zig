/*
 * wdm.h
 *
 * Windows NT WDM Driver Developer Kit
 *
 * This file is part of the ReactOS DDK package.
 *
 * Contributors:
 *   Amine Khaldi
 *   Timo Kreuzer (timo.kreuzer@reactos.org)
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
#pragma once

#ifndef _WDMDDK_
#define _WDMDDK_

#define WDM_MAJORVERSION        0x06
#define WDM_MINORVERSION        0x00

/* Included via ntddk.h? */
#ifndef _NTDDK_
#define _NTDDK_
#define _WDM_INCLUDED_
#define _DDK_DRIVER_
#define NO_INTERLOCKED_INTRINSICS
#endif /* _NTDDK_ */

/* Dependencies */
#define NT_INCLUDED
#include <excpt.h>
#include <ntdef.h>
#include <ntstatus.h>
#include <ntiologc.h>

#ifndef GUID_DEFINED
#include <guiddef.h>
#endif

#ifdef _MAC
#ifndef _INC_STRING
#include <string.h>
#endif /* _INC_STRING */
#else
#include <string.h>
#endif /* _MAC */

#ifndef _KTMTYPES_
typedef GUID UOW, *PUOW;
#endif

typedef GUID *PGUID;

#if (NTDDI_VERSION >= NTDDI_WINXP)
#include <dpfilter.h>
#endif

#include "intrin.h"

#ifdef __cplusplus
extern "C" {
#endif

#if !defined(_NTHALDLL_) && !defined(_BLDR_)
#define NTHALAPI DECLSPEC_IMPORT
#else
#define NTHALAPI
#endif

/* For ReactOS */
#if !defined(_NTOSKRNL_) && !defined(_BLDR_)
#define NTKERNELAPI DECLSPEC_IMPORT
#else
#define NTKERNELAPI
#endif

#if defined(_X86_) && !defined(_NTHAL_)
#define _DECL_HAL_KE_IMPORT  DECLSPEC_IMPORT
#elif defined(_X86_)
#define _DECL_HAL_KE_IMPORT
#else
#define _DECL_HAL_KE_IMPORT NTKERNELAPI
#endif

#if defined(_WIN64)
#define POINTER_ALIGNMENT DECLSPEC_ALIGN(8)
#else
#define POINTER_ALIGNMENT
#endif

#if defined(_MSC_VER)
/* Disable some warnings */
#pragma warning(disable:4115) /* Named type definition in parentheses */
#pragma warning(disable:4201) /* Nameless unions and structs */
#pragma warning(disable:4214) /* Bit fields of other types than int */
#pragma warning(disable:4820) /* Padding added, due to alignemnet requirement */

/* Indicate if #pragma alloc_text() is supported */
#if defined(_M_IX86) || defined(_M_AMD64) || defined(_M_IA64)
#define ALLOC_PRAGMA 1
#endif

/* Indicate if #pragma data_seg() is supported */
#if defined(_M_IX86) || defined(_M_AMD64)
#define ALLOC_DATA_PRAGMA 1
#endif

#endif /* _MSC_VER */

#if defined(_WIN64)
#if !defined(USE_DMA_MACROS) && !defined(_NTHAL_)
#define USE_DMA_MACROS
#endif
#if !defined(NO_LEGACY_DRIVERS) && !defined(__REACTOS__)
#define NO_LEGACY_DRIVERS
#endif
#endif /* defined(_WIN64) */

/* Forward declarations */
struct _IRP;
struct _MDL;
struct _KAPC;
struct _KDPC;
struct _FILE_OBJECT;
struct _DMA_ADAPTER;
struct _DEVICE_OBJECT;
struct _DRIVER_OBJECT;
struct _IO_STATUS_BLOCK;
struct _DEVICE_DESCRIPTION;
struct _SCATTER_GATHER_LIST;
struct _DRIVE_LAYOUT_INFORMATION;
struct _COMPRESSED_DATA_INFO;
struct _IO_RESOURCE_DESCRIPTOR;

/* Structures not exposed to drivers */
typedef struct _OBJECT_TYPE *POBJECT_TYPE;
typedef struct _HAL_DISPATCH_TABLE *PHAL_DISPATCH_TABLE;
typedef struct _HAL_PRIVATE_DISPATCH_TABLE *PHAL_PRIVATE_DISPATCH_TABLE;
typedef struct _CALLBACK_OBJECT *PCALLBACK_OBJECT;
typedef struct _EPROCESS *PEPROCESS;
typedef struct _ETHREAD *PETHREAD;
typedef struct _IO_TIMER *PIO_TIMER;
typedef struct _KINTERRUPT *PKINTERRUPT;
typedef struct _KPROCESS *PKPROCESS;
typedef struct _KTHREAD *PKTHREAD, *PRKTHREAD;
typedef struct _CONTEXT *PCONTEXT;

#if defined(USE_DMA_MACROS) && !defined(_NTHAL_)
typedef struct _DMA_ADAPTER *PADAPTER_OBJECT;
#elif defined(_WDM_INCLUDED_)
typedef struct _DMA_ADAPTER *PADAPTER_OBJECT;
#else
typedef struct _ADAPTER_OBJECT *PADAPTER_OBJECT; 
#endif

#ifndef DEFINE_GUIDEX
#ifdef _MSC_VER
#define DEFINE_GUIDEX(name) EXTERN_C const CDECL GUID name
#else
#define DEFINE_GUIDEX(name) EXTERN_C const GUID name
#endif
#endif /* DEFINE_GUIDEX */

#ifndef STATICGUIDOF
#define STATICGUIDOF(guid) STATIC_##guid
#endif

/* GUID Comparison */
#ifndef __IID_ALIGNED__
#define __IID_ALIGNED__
#ifdef __cplusplus
inline int IsEqualGUIDAligned(REFGUID guid1, REFGUID guid2)
{
    return ( (*(PLONGLONG)(&guid1) == *(PLONGLONG)(&guid2)) && 
             (*((PLONGLONG)(&guid1) + 1) == *((PLONGLONG)(&guid2) + 1)) );
}
#else
#define IsEqualGUIDAligned(guid1, guid2) \
           ( (*(PLONGLONG)(guid1) == *(PLONGLONG)(guid2)) && \
             (*((PLONGLONG)(guid1) + 1) == *((PLONGLONG)(guid2) + 1)) )
#endif /* __cplusplus */
#endif /* !__IID_ALIGNED__ */


/******************************************************************************
 *                           INTERLOCKED Functions                            *
 ******************************************************************************/
//
// Intrinsics (note: taken from our winnt.h)
// FIXME: 64-bit
//
#if defined(__GNUC__)

static __inline__ BOOLEAN
InterlockedBitTestAndSet(
  IN LONG volatile *Base,
  IN LONG Bit)
{
#if defined(_M_IX86)
  LONG OldBit;
  __asm__ __volatile__("lock "
                       "btsl %2,%1\n\t"
                       "sbbl %0,%0\n\t"
                       :"=r" (OldBit),"+m" (*Base)
                       :"Ir" (Bit)
                       : "memory");
  return OldBit;
#else
  return (_InterlockedOr(Base, 1 << Bit) >> Bit) & 1;
#endif
}

static __inline__ BOOLEAN
InterlockedBitTestAndReset(
  IN LONG volatile *Base,
  IN LONG Bit)
{
#if defined(_M_IX86)
  LONG OldBit;
  __asm__ __volatile__("lock "
                       "btrl %2,%1\n\t"
                       "sbbl %0,%0\n\t"
                       :"=r" (OldBit),"+m" (*Base)
                       :"Ir" (Bit)
                       : "memory");
  return OldBit;
#else
  return (_InterlockedAnd(Base, ~(1 << Bit)) >> Bit) & 1;
#endif
}

#endif /* defined(__GNUC__) */

#define BitScanForward _BitScanForward
#define BitScanReverse _BitScanReverse
#define BitTest _bittest
#define BitTestAndComplement _bittestandcomplement
#define BitTestAndSet _bittestandset
#define BitTestAndReset _bittestandreset
#define InterlockedBitTestAndSet _interlockedbittestandset
#define InterlockedBitTestAndReset _interlockedbittestandreset

#ifdef _M_AMD64
#define BitTest64 _bittest64
#define BitTestAndComplement64 _bittestandcomplement64
#define BitTestAndSet64 _bittestandset64
#define BitTestAndReset64 _bittestandreset64
#define InterlockedBitTestAndSet64 _interlockedbittestandset64
#define InterlockedBitTestAndReset64 _interlockedbittestandreset64
#endif

#if !defined(__INTERLOCKED_DECLARED)
#define __INTERLOCKED_DECLARED

#if defined (_X86_)
#if defined(NO_INTERLOCKED_INTRINSICS)
NTKERNELAPI
LONG
FASTCALL
InterlockedIncrement(
  IN OUT LONG volatile *Addend);

NTKERNELAPI
LONG
FASTCALL
InterlockedDecrement(
  IN OUT LONG volatile *Addend);

NTKERNELAPI
LONG
FASTCALL
InterlockedCompareExchange(
  IN OUT LONG volatile *Destination,
  IN LONG Exchange,
  IN LONG Comparand);

NTKERNELAPI
LONG
FASTCALL
InterlockedExchange(
  IN OUT LONG volatile *Destination,
  IN LONG Value);

NTKERNELAPI
LONG
FASTCALL
InterlockedExchangeAdd(
  IN OUT LONG volatile *Addend,
  IN LONG  Value);

#else /* !defined(NO_INTERLOCKED_INTRINSICS) */

#define InterlockedExchange _InterlockedExchange
#define InterlockedIncrement _InterlockedIncrement
#define InterlockedDecrement _InterlockedDecrement
#define InterlockedExchangeAdd _InterlockedExchangeAdd
#define InterlockedCompareExchange _InterlockedCompareExchange
#define InterlockedOr _InterlockedOr
#define InterlockedAnd _InterlockedAnd
#define InterlockedXor _InterlockedXor

#endif /* !defined(NO_INTERLOCKED_INTRINSICS) */

#endif /* defined (_X86_) */

#if !defined (_WIN64)
/*
 * PVOID
 * InterlockedExchangePointer(
 *   IN OUT PVOID volatile  *Target,
 *   IN PVOID  Value)
 */
#define InterlockedExchangePointer(Target, Value) \
  ((PVOID) InterlockedExchange((PLONG) Target, (LONG) Value))

/*
 * PVOID
 * InterlockedCompareExchangePointer(
 *   IN OUT PVOID  *Destination,
 *   IN PVOID  Exchange,
 *   IN PVOID  Comparand)
 */
#define InterlockedCompareExchangePointer(Destination, Exchange, Comparand) \
  ((PVOID) InterlockedCompareExchange((PLONG) Destination, (LONG) Exchange, (LONG) Comparand))

#define InterlockedExchangeAddSizeT(a, b) InterlockedExchangeAdd((LONG *)a, b)
#define InterlockedIncrementSizeT(a) InterlockedIncrement((LONG *)a)
#define InterlockedDecrementSizeT(a) InterlockedDecrement((LONG *)a)

#endif // !defined (_WIN64)

#if defined (_M_AMD64)

#define InterlockedExchangeAddSizeT(a, b) InterlockedExchangeAdd64((LONGLONG *)a, (LONGLONG)b)
#define InterlockedIncrementSizeT(a) InterlockedIncrement64((LONGLONG *)a)
#define InterlockedDecrementSizeT(a) InterlockedDecrement64((LONGLONG *)a)
#define InterlockedAnd _InterlockedAnd
#define InterlockedOr _InterlockedOr
#define InterlockedXor _InterlockedXor
#define InterlockedIncrement _InterlockedIncrement
#define InterlockedDecrement _InterlockedDecrement
#define InterlockedAdd _InterlockedAdd
#define InterlockedExchange _InterlockedExchange
#define InterlockedExchangeAdd _InterlockedExchangeAdd
#define InterlockedCompareExchange _InterlockedCompareExchange
#define InterlockedAnd64 _InterlockedAnd64
#define InterlockedOr64 _InterlockedOr64
#define InterlockedXor64 _InterlockedXor64
#define InterlockedIncrement64 _InterlockedIncrement64
#define InterlockedDecrement64 _InterlockedDecrement64
#define InterlockedAdd64 _InterlockedAdd64
#define InterlockedExchange64 _InterlockedExchange64
#define InterlockedExchangeAdd64 _InterlockedExchangeAdd64
#define InterlockedCompareExchange64 _InterlockedCompareExchange64
#define InterlockedCompareExchangePointer _InterlockedCompareExchangePointer
#define InterlockedExchangePointer _InterlockedExchangePointer
#define InterlockedBitTestAndSet64 _interlockedbittestandset64
#define InterlockedBitTestAndReset64 _interlockedbittestandreset64

#endif // _M_AMD64

#if defined(_M_AMD64) && !defined(RC_INVOKED) && !defined(MIDL_PASS)
//#if !defined(_X86AMD64_) // FIXME: what's _X86AMD64_ used for?
FORCEINLINE
LONG64
InterlockedAdd64(
  IN OUT LONG64 volatile *Addend,
  IN LONG64 Value)
{
  return InterlockedExchangeAdd64(Addend, Value) + Value;
}
//#endif
#endif

#endif /* !__INTERLOCKED_DECLARED */


/******************************************************************************
 *                           Runtime Library Types                            *
 ******************************************************************************/

#define RTL_REGISTRY_ABSOLUTE             0
#define RTL_REGISTRY_SERVICES             1
#define RTL_REGISTRY_CONTROL              2
#define RTL_REGISTRY_WINDOWS_NT           3
#define RTL_REGISTRY_DEVICEMAP            4
#define RTL_REGISTRY_USER                 5
#define RTL_REGISTRY_MAXIMUM              6
#define RTL_REGISTRY_HANDLE               0x40000000
#define RTL_REGISTRY_OPTIONAL             0x80000000

/* RTL_QUERY_REGISTRY_TABLE.Flags */
#define RTL_QUERY_REGISTRY_SUBKEY         0x00000001
#define RTL_QUERY_REGISTRY_TOPKEY         0x00000002
#define RTL_QUERY_REGISTRY_REQUIRED       0x00000004
#define RTL_QUERY_REGISTRY_NOVALUE        0x00000008
#define RTL_QUERY_REGISTRY_NOEXPAND       0x00000010
#define RTL_QUERY_REGISTRY_DIRECT         0x00000020
#define RTL_QUERY_REGISTRY_DELETE         0x00000040

#define HASH_STRING_ALGORITHM_DEFAULT     0
#define HASH_STRING_ALGORITHM_X65599      1
#define HASH_STRING_ALGORITHM_INVALID     0xffffffff

typedef struct _RTL_BITMAP {
  ULONG SizeOfBitMap;
  PULONG Buffer;
} RTL_BITMAP, *PRTL_BITMAP;

typedef struct _RTL_BITMAP_RUN {
  ULONG StartingIndex;
  ULONG NumberOfBits;
} RTL_BITMAP_RUN, *PRTL_BITMAP_RUN;

typedef NTSTATUS
(NTAPI *PRTL_QUERY_REGISTRY_ROUTINE)(
  IN PWSTR ValueName,
  IN ULONG ValueType,
  IN PVOID ValueData,
  IN ULONG ValueLength,
  IN PVOID Context,
  IN PVOID EntryContext);

typedef struct _RTL_QUERY_REGISTRY_TABLE {
  PRTL_QUERY_REGISTRY_ROUTINE QueryRoutine;
  ULONG Flags;
  PCWSTR Name;
  PVOID EntryContext;
  ULONG DefaultType;
  PVOID DefaultData;
  ULONG DefaultLength;
} RTL_QUERY_REGISTRY_TABLE, *PRTL_QUERY_REGISTRY_TABLE;

typedef struct _TIME_FIELDS {
  CSHORT Year;
  CSHORT Month;
  CSHORT Day;
  CSHORT Hour;
  CSHORT Minute;
  CSHORT Second;
  CSHORT Milliseconds;
  CSHORT Weekday;
} TIME_FIELDS, *PTIME_FIELDS;

/* Slist Header */
#ifndef _SLIST_HEADER_
#define _SLIST_HEADER_

#if defined(_WIN64)

typedef struct DECLSPEC_ALIGN(16) _SLIST_ENTRY {
  struct _SLIST_ENTRY *Next;
} SLIST_ENTRY, *PSLIST_ENTRY;

typedef struct _SLIST_ENTRY32 {
  ULONG Next;
} SLIST_ENTRY32, *PSLIST_ENTRY32;

typedef union DECLSPEC_ALIGN(16) _SLIST_HEADER {
  _ANONYMOUS_STRUCT struct {
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
    ULONGLONG Init:1;
    ULONGLONG Reserved:2;
    ULONGLONG NextEntry:60;
  } Header16;
  struct {
    ULONGLONG Depth:16;
    ULONGLONG Sequence:48;
    ULONGLONG HeaderType:1;
    ULONGLONG Reserved:3;
    ULONGLONG NextEntry:60;
  } HeaderX64;
} SLIST_HEADER, *PSLIST_HEADER;

typedef union _SLIST_HEADER32 {
  ULONGLONG Alignment;
  _ANONYMOUS_STRUCT struct {
    SLIST_ENTRY32 Next;
    USHORT Depth;
    USHORT Sequence;
  } DUMMYSTRUCTNAME;
} SLIST_HEADER32, *PSLIST_HEADER32;

#else

#define SLIST_ENTRY SINGLE_LIST_ENTRY
#define _SLIST_ENTRY _SINGLE_LIST_ENTRY
#define PSLIST_ENTRY PSINGLE_LIST_ENTRY

typedef SLIST_ENTRY SLIST_ENTRY32, *PSLIST_ENTRY32;

typedef union _SLIST_HEADER {
  ULONGLONG Alignment;
  _ANONYMOUS_STRUCT struct {
    SLIST_ENTRY Next;
    USHORT Depth;
    USHORT Sequence;
  } DUMMYSTRUCTNAME;
} SLIST_HEADER, *PSLIST_HEADER;

typedef SLIST_HEADER SLIST_HEADER32, *PSLIST_HEADER32;

#endif /* defined(_WIN64) */

#endif /* _SLIST_HEADER_ */

/* MS definition is broken! */
extern BOOLEAN NTSYSAPI NlsMbCodePageTag;
extern BOOLEAN NTSYSAPI NlsMbOemCodePageTag;
#define NLS_MB_CODE_PAGE_TAG NlsMbCodePageTag
#define NLS_MB_OEM_CODE_PAGE_TAG NlsMbOemCodePageTag

#define SHORT_LEAST_SIGNIFICANT_BIT       0
#define SHORT_MOST_SIGNIFICANT_BIT        1

#define LONG_LEAST_SIGNIFICANT_BIT        0
#define LONG_3RD_MOST_SIGNIFICANT_BIT     1
#define LONG_2ND_MOST_SIGNIFICANT_BIT     2
#define LONG_MOST_SIGNIFICANT_BIT         3

#define RTLVERLIB_DDI(x) Wdmlib##x

typedef BOOLEAN
(*PFN_RTL_IS_NTDDI_VERSION_AVAILABLE)(
  IN ULONG Version);

typedef BOOLEAN
(*PFN_RTL_IS_SERVICE_PACK_VERSION_INSTALLED)(
  IN ULONG Version);

/******************************************************************************
 *                              Kernel Types                                  *
 ******************************************************************************/

typedef UCHAR KIRQL, *PKIRQL;
typedef CCHAR KPROCESSOR_MODE;
typedef LONG KPRIORITY;

typedef enum _MODE {
  KernelMode,
  UserMode,
  MaximumMode
} MODE;

#define CACHE_FULLY_ASSOCIATIVE 0xFF
#define MAXIMUM_SUSPEND_COUNT   MAXCHAR

#define EVENT_QUERY_STATE (0x0001)
#define EVENT_MODIFY_STATE (0x0002)
#define EVENT_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0x3)

#define LTP_PC_SMT 0x1

#if (NTDDI_VERSION < NTDDI_WIN7) || defined(_X86_) || !defined(NT_PROCESSOR_GROUPS)
#define SINGLE_GROUP_LEGACY_API        1
#endif

#define SEMAPHORE_QUERY_STATE (0x0001)
#define SEMAPHORE_MODIFY_STATE (0x0002)
#define SEMAPHORE_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0x3)

typedef enum _LOGICAL_PROCESSOR_RELATIONSHIP {
  RelationProcessorCore,
  RelationNumaNode,
  RelationCache,
  RelationProcessorPackage,
  RelationGroup,
  RelationAll = 0xffff
} LOGICAL_PROCESSOR_RELATIONSHIP;

typedef enum _PROCESSOR_CACHE_TYPE {
  CacheUnified,
  CacheInstruction,
  CacheData,
  CacheTrace
} PROCESSOR_CACHE_TYPE;

typedef struct _CACHE_DESCRIPTOR {
  UCHAR Level;
  UCHAR Associativity;
  USHORT LineSize;
  ULONG Size;
  PROCESSOR_CACHE_TYPE Type;
} CACHE_DESCRIPTOR, *PCACHE_DESCRIPTOR;

typedef struct _SYSTEM_LOGICAL_PROCESSOR_INFORMATION {
  ULONG_PTR ProcessorMask;
  LOGICAL_PROCESSOR_RELATIONSHIP Relationship;
  _ANONYMOUS_UNION union {
    struct {
      UCHAR Flags;
    } ProcessorCore;
    struct {
      ULONG NodeNumber;
    } NumaNode;
    CACHE_DESCRIPTOR Cache;
    ULONGLONG Reserved[2];
  } DUMMYUNIONNAME;
} SYSTEM_LOGICAL_PROCESSOR_INFORMATION, *PSYSTEM_LOGICAL_PROCESSOR_INFORMATION;

typedef struct _PROCESSOR_RELATIONSHIP {
  UCHAR Flags;
  UCHAR Reserved[21];
  USHORT GroupCount;
  GROUP_AFFINITY GroupMask[ANYSIZE_ARRAY];
} PROCESSOR_RELATIONSHIP, *PPROCESSOR_RELATIONSHIP;

typedef struct _NUMA_NODE_RELATIONSHIP {
  ULONG NodeNumber;
  UCHAR Reserved[20];
  GROUP_AFFINITY GroupMask;
} NUMA_NODE_RELATIONSHIP, *PNUMA_NODE_RELATIONSHIP;

typedef struct _CACHE_RELATIONSHIP {
  UCHAR Level;
  UCHAR Associativity;
  USHORT LineSize;
  ULONG CacheSize;
  PROCESSOR_CACHE_TYPE Type;
  UCHAR Reserved[20];
  GROUP_AFFINITY GroupMask;
} CACHE_RELATIONSHIP, *PCACHE_RELATIONSHIP;

typedef struct _PROCESSOR_GROUP_INFO {
  UCHAR MaximumProcessorCount;
  UCHAR ActiveProcessorCount;
  UCHAR Reserved[38];
  KAFFINITY ActiveProcessorMask;
} PROCESSOR_GROUP_INFO, *PPROCESSOR_GROUP_INFO;

typedef struct _GROUP_RELATIONSHIP {
  USHORT MaximumGroupCount;
  USHORT ActiveGroupCount;
  UCHAR Reserved[20];
  PROCESSOR_GROUP_INFO GroupInfo[ANYSIZE_ARRAY];
} GROUP_RELATIONSHIP, *PGROUP_RELATIONSHIP;

typedef struct _SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX {
  LOGICAL_PROCESSOR_RELATIONSHIP Relationship;
  ULONG Size;
  _ANONYMOUS_UNION union {
    PROCESSOR_RELATIONSHIP Processor;
    NUMA_NODE_RELATIONSHIP NumaNode;
    CACHE_RELATIONSHIP Cache;
    GROUP_RELATIONSHIP Group;
  } DUMMYUNIONNAME;
} SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX, *PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX;

/* Processor features */
#define PF_FLOATING_POINT_PRECISION_ERRATA  0
#define PF_FLOATING_POINT_EMULATED          1
#define PF_COMPARE_EXCHANGE_DOUBLE          2
#define PF_MMX_INSTRUCTIONS_AVAILABLE       3
#define PF_PPC_MOVEMEM_64BIT_OK             4
#define PF_ALPHA_BYTE_INSTRUCTIONS          5
#define PF_XMMI_INSTRUCTIONS_AVAILABLE      6
#define PF_3DNOW_INSTRUCTIONS_AVAILABLE     7
#define PF_RDTSC_INSTRUCTION_AVAILABLE      8
#define PF_PAE_ENABLED                      9
#define PF_XMMI64_INSTRUCTIONS_AVAILABLE   10
#define PF_SSE_DAZ_MODE_AVAILABLE          11
#define PF_NX_ENABLED                      12
#define PF_SSE3_INSTRUCTIONS_AVAILABLE     13
#define PF_COMPARE_EXCHANGE128             14
#define PF_COMPARE64_EXCHANGE128           15
#define PF_CHANNELS_ENABLED                16
#define PF_XSAVE_ENABLED                   17

#define MAXIMUM_WAIT_OBJECTS              64

#define ASSERT_APC(Object) NT_ASSERT((Object)->Type == ApcObject)

#define ASSERT_DPC(Object) \
    ASSERT(((Object)->Type == 0) || \
           ((Object)->Type == DpcObject) || \
           ((Object)->Type == ThreadedDpcObject))

#define ASSERT_GATE(object) \
    NT_ASSERT((((object)->Header.Type & KOBJECT_TYPE_MASK) == GateObject) || \
              (((object)->Header.Type & KOBJECT_TYPE_MASK) == EventSynchronizationObject))

#define ASSERT_DEVICE_QUEUE(Object) \
    NT_ASSERT((Object)->Type == DeviceQueueObject)

#define ASSERT_TIMER(E) \
    NT_ASSERT(((E)->Header.Type == TimerNotificationObject) || \
              ((E)->Header.Type == TimerSynchronizationObject))

#define ASSERT_MUTANT(E) \
    NT_ASSERT((E)->Header.Type == MutantObject)

#define ASSERT_SEMAPHORE(E) \
    NT_ASSERT((E)->Header.Type == SemaphoreObject)

#define ASSERT_EVENT(E) \
    NT_ASSERT(((E)->Header.Type == NotificationEvent) || \
              ((E)->Header.Type == SynchronizationEvent))

#define DPC_NORMAL 0
#define DPC_THREADED 1

#define GM_LOCK_BIT          0x1
#define GM_LOCK_BIT_V        0x0
#define GM_LOCK_WAITER_WOKEN 0x2
#define GM_LOCK_WAITER_INC   0x4

#define LOCK_QUEUE_WAIT_BIT               0
#define LOCK_QUEUE_OWNER_BIT              1

#define LOCK_QUEUE_WAIT                   1
#define LOCK_QUEUE_OWNER                  2
#define LOCK_QUEUE_TIMER_LOCK_SHIFT       4
#define LOCK_QUEUE_TIMER_TABLE_LOCKS (1 << (8 - LOCK_QUEUE_TIMER_LOCK_SHIFT))

#define PROCESSOR_FEATURE_MAX 64

#define DBG_STATUS_CONTROL_C              1
#define DBG_STATUS_SYSRQ                  2
#define DBG_STATUS_BUGCHECK_FIRST         3
#define DBG_STATUS_BUGCHECK_SECOND        4
#define DBG_STATUS_FATAL                  5
#define DBG_STATUS_DEBUG_CONTROL          6
#define DBG_STATUS_WORKER                 7

#if defined(_WIN64)
#define MAXIMUM_PROC_PER_GROUP 64
#else
#define MAXIMUM_PROC_PER_GROUP 32
#endif
#define MAXIMUM_PROCESSORS          MAXIMUM_PROC_PER_GROUP

/* Exception Records */
#define EXCEPTION_NONCONTINUABLE     1
#define EXCEPTION_MAXIMUM_PARAMETERS 15

#define EXCEPTION_DIVIDED_BY_ZERO       0
#define EXCEPTION_DEBUG                 1
#define EXCEPTION_NMI                   2
#define EXCEPTION_INT3                  3
#define EXCEPTION_BOUND_CHECK           5
#define EXCEPTION_INVALID_OPCODE        6
#define EXCEPTION_NPX_NOT_AVAILABLE     7
#define EXCEPTION_DOUBLE_FAULT          8
#define EXCEPTION_NPX_OVERRUN           9
#define EXCEPTION_INVALID_TSS           0x0A
#define EXCEPTION_SEGMENT_NOT_PRESENT   0x0B
#define EXCEPTION_STACK_FAULT           0x0C
#define EXCEPTION_GP_FAULT              0x0D
#define EXCEPTION_RESERVED_TRAP         0x0F
#define EXCEPTION_NPX_ERROR             0x010
#define EXCEPTION_ALIGNMENT_CHECK       0x011

typedef struct _EXCEPTION_RECORD {
  NTSTATUS ExceptionCode;
  ULONG ExceptionFlags;
  struct _EXCEPTION_RECORD *ExceptionRecord;
  PVOID ExceptionAddress;
  ULONG NumberParameters;
  ULONG_PTR ExceptionInformation[EXCEPTION_MAXIMUM_PARAMETERS];
} EXCEPTION_RECORD, *PEXCEPTION_RECORD;

typedef struct _EXCEPTION_RECORD32 {
  NTSTATUS ExceptionCode;
  ULONG ExceptionFlags;
  ULONG ExceptionRecord;
  ULONG ExceptionAddress;
  ULONG NumberParameters;
  ULONG ExceptionInformation[EXCEPTION_MAXIMUM_PARAMETERS];
} EXCEPTION_RECORD32, *PEXCEPTION_RECORD32;

typedef struct _EXCEPTION_RECORD64 {
  NTSTATUS ExceptionCode;
  ULONG ExceptionFlags;
  ULONG64 ExceptionRecord;
  ULONG64 ExceptionAddress;
  ULONG NumberParameters;
  ULONG __unusedAlignment;
  ULONG64 ExceptionInformation[EXCEPTION_MAXIMUM_PARAMETERS];
} EXCEPTION_RECORD64, *PEXCEPTION_RECORD64;

typedef struct _EXCEPTION_POINTERS {
  PEXCEPTION_RECORD ExceptionRecord;
  PCONTEXT ContextRecord;
} EXCEPTION_POINTERS, *PEXCEPTION_POINTERS;

typedef enum _KBUGCHECK_CALLBACK_REASON {
  KbCallbackInvalid,
  KbCallbackReserved1,
  KbCallbackSecondaryDumpData,
  KbCallbackDumpIo,
  KbCallbackAddPages
} KBUGCHECK_CALLBACK_REASON;

struct _KBUGCHECK_REASON_CALLBACK_RECORD;

typedef VOID
(NTAPI KBUGCHECK_REASON_CALLBACK_ROUTINE)(
  IN KBUGCHECK_CALLBACK_REASON Reason,
  IN struct _KBUGCHECK_REASON_CALLBACK_RECORD *Record,
  IN OUT PVOID ReasonSpecificData,
  IN ULONG ReasonSpecificDataLength);
typedef KBUGCHECK_REASON_CALLBACK_ROUTINE *PKBUGCHECK_REASON_CALLBACK_ROUTINE;

typedef struct _KBUGCHECK_ADD_PAGES {
  IN OUT PVOID Context;
  IN OUT ULONG Flags;
  IN ULONG BugCheckCode;
  OUT ULONG_PTR Address;
  OUT ULONG_PTR Count;
} KBUGCHECK_ADD_PAGES, *PKBUGCHECK_ADD_PAGES;

typedef struct _KBUGCHECK_SECONDARY_DUMP_DATA {
  IN PVOID InBuffer;
  IN ULONG InBufferLength;
  IN ULONG MaximumAllowed;
  OUT GUID Guid;
  OUT PVOID OutBuffer;
  OUT ULONG OutBufferLength;
} KBUGCHECK_SECONDARY_DUMP_DATA, *PKBUGCHECK_SECONDARY_DUMP_DATA;

typedef enum _KBUGCHECK_DUMP_IO_TYPE {
  KbDumpIoInvalid,
  KbDumpIoHeader,
  KbDumpIoBody,
  KbDumpIoSecondaryData,
  KbDumpIoComplete
} KBUGCHECK_DUMP_IO_TYPE;

typedef struct _KBUGCHECK_DUMP_IO {
  IN ULONG64 Offset;
  IN PVOID Buffer;
  IN ULONG BufferLength;
  IN KBUGCHECK_DUMP_IO_TYPE Type;
} KBUGCHECK_DUMP_IO, *PKBUGCHECK_DUMP_IO;

#define KB_ADD_PAGES_FLAG_VIRTUAL_ADDRESS         0x00000001UL
#define KB_ADD_PAGES_FLAG_PHYSICAL_ADDRESS        0x00000002UL
#define KB_ADD_PAGES_FLAG_ADDITIONAL_RANGES_EXIST 0x80000000UL

typedef struct _KBUGCHECK_REASON_CALLBACK_RECORD {
  LIST_ENTRY Entry;
  PKBUGCHECK_REASON_CALLBACK_ROUTINE CallbackRoutine;
  PUCHAR Component;
  ULONG_PTR Checksum;
  KBUGCHECK_CALLBACK_REASON Reason;
  UCHAR State;
} KBUGCHECK_REASON_CALLBACK_RECORD, *PKBUGCHECK_REASON_CALLBACK_RECORD;

typedef enum _KBUGCHECK_BUFFER_DUMP_STATE {
  BufferEmpty,
  BufferInserted,
  BufferStarted,
  BufferFinished,
  BufferIncomplete
} KBUGCHECK_BUFFER_DUMP_STATE;

typedef VOID
(NTAPI KBUGCHECK_CALLBACK_ROUTINE)(
  IN PVOID Buffer,
  IN ULONG Length);
typedef KBUGCHECK_CALLBACK_ROUTINE *PKBUGCHECK_CALLBACK_ROUTINE;

typedef struct _KBUGCHECK_CALLBACK_RECORD {
  LIST_ENTRY Entry;
  PKBUGCHECK_CALLBACK_ROUTINE CallbackRoutine;
  PVOID Buffer;
  ULONG Length;
  PUCHAR Component;
  ULONG_PTR Checksum;
  UCHAR State;
} KBUGCHECK_CALLBACK_RECORD, *PKBUGCHECK_CALLBACK_RECORD;

typedef BOOLEAN
(NTAPI NMI_CALLBACK)(
  IN PVOID Context,
  IN BOOLEAN Handled);
typedef NMI_CALLBACK *PNMI_CALLBACK;

typedef enum _KE_PROCESSOR_CHANGE_NOTIFY_STATE {
  KeProcessorAddStartNotify = 0,
  KeProcessorAddCompleteNotify,
  KeProcessorAddFailureNotify
} KE_PROCESSOR_CHANGE_NOTIFY_STATE;

typedef struct _KE_PROCESSOR_CHANGE_NOTIFY_CONTEXT {
  KE_PROCESSOR_CHANGE_NOTIFY_STATE State;
  ULONG NtNumber;
  NTSTATUS Status;
#if (NTDDI_VERSION >= NTDDI_WIN7)
  PROCESSOR_NUMBER ProcNumber;
#endif
} KE_PROCESSOR_CHANGE_NOTIFY_CONTEXT, *PKE_PROCESSOR_CHANGE_NOTIFY_CONTEXT;

typedef VOID
(NTAPI PROCESSOR_CALLBACK_FUNCTION)(
  IN PVOID CallbackContext,
  IN PKE_PROCESSOR_CHANGE_NOTIFY_CONTEXT ChangeContext,
  IN OUT PNTSTATUS OperationStatus);
typedef PROCESSOR_CALLBACK_FUNCTION *PPROCESSOR_CALLBACK_FUNCTION;

#define KE_PROCESSOR_CHANGE_ADD_EXISTING         1

#define INVALID_PROCESSOR_INDEX     0xffffffff

typedef enum _KINTERRUPT_POLARITY {
  InterruptPolarityUnknown,
  InterruptActiveHigh,
  InterruptActiveLow
} KINTERRUPT_POLARITY, *PKINTERRUPT_POLARITY;

typedef enum _KPROFILE_SOURCE {
  ProfileTime,
  ProfileAlignmentFixup,
  ProfileTotalIssues,
  ProfilePipelineDry,
  ProfileLoadInstructions,
  ProfilePipelineFrozen,
  ProfileBranchInstructions,
  ProfileTotalNonissues,
  ProfileDcacheMisses,
  ProfileIcacheMisses,
  ProfileCacheMisses,
  ProfileBranchMispredictions,
  ProfileStoreInstructions,
  ProfileFpInstructions,
  ProfileIntegerInstructions,
  Profile2Issue,
  Profile3Issue,
  Profile4Issue,
  ProfileSpecialInstructions,
  ProfileTotalCycles,
  ProfileIcacheIssues,
  ProfileDcacheAccesses,
  ProfileMemoryBarrierCycles,
  ProfileLoadLinkedIssues,
  ProfileMaximum
} KPROFILE_SOURCE;

typedef enum _KWAIT_REASON {
  Executive,
  FreePage,
  PageIn,
  PoolAllocation,
  DelayExecution,
  Suspended,
  UserRequest,
  WrExecutive,
  WrFreePage,
  WrPageIn,
  WrPoolAllocation,
  WrDelayExecution,
  WrSuspended,
  WrUserRequest,
  WrEventPair,
  WrQueue,
  WrLpcReceive,
  WrLpcReply,
  WrVirtualMemory,
  WrPageOut,
  WrRendezvous,
  WrKeyedEvent,
  WrTerminated,
  WrProcessInSwap,
  WrCpuRateControl,
  WrCalloutStack,
  WrKernel,
  WrResource,
  WrPushLock,
  WrMutex,
  WrQuantumEnd,
  WrDispatchInt,
  WrPreempted,
  WrYieldExecution,
  WrFastMutex,
  WrGuardedMutex,
  WrRundown,
  MaximumWaitReason
} KWAIT_REASON;

typedef struct _KWAIT_BLOCK {
  LIST_ENTRY WaitListEntry;
  struct _KTHREAD *Thread;
  PVOID Object;
  struct _KWAIT_BLOCK *NextWaitBlock;
  USHORT WaitKey;
  UCHAR WaitType;
  volatile UCHAR BlockState;
#if defined(_WIN64)
  LONG SpareLong;
#endif
} KWAIT_BLOCK, *PKWAIT_BLOCK, *PRKWAIT_BLOCK;

typedef enum _KINTERRUPT_MODE {
  LevelSensitive,
  Latched
} KINTERRUPT_MODE;

#define THREAD_WAIT_OBJECTS 3

typedef VOID
(NTAPI KSTART_ROUTINE)(
  IN PVOID StartContext);
typedef KSTART_ROUTINE *PKSTART_ROUTINE;

typedef VOID
(NTAPI *PKINTERRUPT_ROUTINE)(
  VOID);

typedef BOOLEAN
(NTAPI KSERVICE_ROUTINE)(
  IN struct _KINTERRUPT *Interrupt,
  IN PVOID ServiceContext);
typedef KSERVICE_ROUTINE *PKSERVICE_ROUTINE;

typedef BOOLEAN
(NTAPI KMESSAGE_SERVICE_ROUTINE)(
  IN struct _KINTERRUPT *Interrupt,
  IN PVOID ServiceContext,
  IN ULONG MessageID);
typedef KMESSAGE_SERVICE_ROUTINE *PKMESSAGE_SERVICE_ROUTINE;

typedef enum _KD_OPTION {
  KD_OPTION_SET_BLOCK_ENABLE,
} KD_OPTION;

typedef VOID
(NTAPI *PKNORMAL_ROUTINE)(
  IN PVOID NormalContext OPTIONAL,
  IN PVOID SystemArgument1 OPTIONAL,
  IN PVOID SystemArgument2 OPTIONAL);

typedef VOID
(NTAPI *PKRUNDOWN_ROUTINE)(
  IN struct _KAPC *Apc);

typedef VOID
(NTAPI *PKKERNEL_ROUTINE)(
  IN struct _KAPC *Apc,
  IN OUT PKNORMAL_ROUTINE *NormalRoutine OPTIONAL,
  IN OUT PVOID *NormalContext OPTIONAL,
  IN OUT PVOID *SystemArgument1 OPTIONAL,
  IN OUT PVOID *SystemArgument2 OPTIONAL);

typedef struct _KAPC {
  UCHAR Type;
  UCHAR SpareByte0;
  UCHAR Size;
  UCHAR SpareByte1;
  ULONG SpareLong0;
  struct _KTHREAD *Thread;
  LIST_ENTRY ApcListEntry;
  PKKERNEL_ROUTINE KernelRoutine;
  PKRUNDOWN_ROUTINE RundownRoutine;
  PKNORMAL_ROUTINE NormalRoutine;
  PVOID NormalContext;
  PVOID SystemArgument1;
  PVOID SystemArgument2;
  CCHAR ApcStateIndex;
  KPROCESSOR_MODE ApcMode;
  BOOLEAN Inserted;
} KAPC, *PKAPC, *RESTRICTED_POINTER PRKAPC;

#define KAPC_OFFSET_TO_SPARE_BYTE0 FIELD_OFFSET(KAPC, SpareByte0)
#define KAPC_OFFSET_TO_SPARE_BYTE1 FIELD_OFFSET(KAPC, SpareByte1)
#define KAPC_OFFSET_TO_SPARE_LONG FIELD_OFFSET(KAPC, SpareLong0)
#define KAPC_OFFSET_TO_SYSTEMARGUMENT1 FIELD_OFFSET(KAPC, SystemArgument1)
#define KAPC_OFFSET_TO_SYSTEMARGUMENT2 FIELD_OFFSET(KAPC, SystemArgument2)
#define KAPC_OFFSET_TO_APCSTATEINDEX FIELD_OFFSET(KAPC, ApcStateIndex)
#define KAPC_ACTUAL_LENGTH (FIELD_OFFSET(KAPC, Inserted) + sizeof(BOOLEAN))

typedef struct _KDEVICE_QUEUE_ENTRY {
  LIST_ENTRY DeviceListEntry;
  ULONG SortKey;
  BOOLEAN Inserted;
} KDEVICE_QUEUE_ENTRY, *PKDEVICE_QUEUE_ENTRY,
*RESTRICTED_POINTER PRKDEVICE_QUEUE_ENTRY;

typedef PVOID PKIPI_CONTEXT;

typedef VOID
(NTAPI *PKIPI_WORKER)(
  IN OUT PKIPI_CONTEXT PacketContext,
  IN PVOID Parameter1 OPTIONAL,
  IN PVOID Parameter2 OPTIONAL,
  IN PVOID Parameter3 OPTIONAL);

typedef struct _KIPI_COUNTS {
  ULONG Freeze;
  ULONG Packet;
  ULONG DPC;
  ULONG APC;
  ULONG FlushSingleTb;
  ULONG FlushMultipleTb;
  ULONG FlushEntireTb;
  ULONG GenericCall;
  ULONG ChangeColor;
  ULONG SweepDcache;
  ULONG SweepIcache;
  ULONG SweepIcacheRange;
  ULONG FlushIoBuffers;
  ULONG GratuitousDPC;
} KIPI_COUNTS, *PKIPI_COUNTS;

typedef ULONG_PTR
(NTAPI KIPI_BROADCAST_WORKER)(
  IN ULONG_PTR Argument);
typedef KIPI_BROADCAST_WORKER *PKIPI_BROADCAST_WORKER;

typedef ULONG_PTR KSPIN_LOCK, *PKSPIN_LOCK;

typedef struct _KSPIN_LOCK_QUEUE {
  struct _KSPIN_LOCK_QUEUE *volatile Next;
  PKSPIN_LOCK volatile Lock;
} KSPIN_LOCK_QUEUE, *PKSPIN_LOCK_QUEUE;

typedef struct _KLOCK_QUEUE_HANDLE {
  KSPIN_LOCK_QUEUE LockQueue;
  KIRQL OldIrql;
} KLOCK_QUEUE_HANDLE, *PKLOCK_QUEUE_HANDLE;

#if defined(_AMD64_)

typedef ULONG64 KSPIN_LOCK_QUEUE_NUMBER;

#define LockQueueDispatcherLock 0
#define LockQueueExpansionLock 1
#define LockQueuePfnLock 2
#define LockQueueSystemSpaceLock 3
#define LockQueueVacbLock 4
#define LockQueueMasterLock 5
#define LockQueueNonPagedPoolLock 6
#define LockQueueIoCancelLock 7
#define LockQueueWorkQueueLock 8
#define LockQueueIoVpbLock 9
#define LockQueueIoDatabaseLock 10
#define LockQueueIoCompletionLock 11
#define LockQueueNtfsStructLock 12
#define LockQueueAfdWorkQueueLock 13
#define LockQueueBcbLock 14
#define LockQueueMmNonPagedPoolLock 15
#define LockQueueUnusedSpare16 16
#define LockQueueTimerTableLock 17
#define LockQueueMaximumLock (LockQueueTimerTableLock + LOCK_QUEUE_TIMER_TABLE_LOCKS)

#else

typedef enum _KSPIN_LOCK_QUEUE_NUMBER {
  LockQueueDispatcherLock,
  LockQueueExpansionLock,
  LockQueuePfnLock,
  LockQueueSystemSpaceLock,
  LockQueueVacbLock,
  LockQueueMasterLock,
  LockQueueNonPagedPoolLock,
  LockQueueIoCancelLock,
  LockQueueWorkQueueLock,
  LockQueueIoVpbLock,
  LockQueueIoDatabaseLock,
  LockQueueIoCompletionLock,
  LockQueueNtfsStructLock,
  LockQueueAfdWorkQueueLock,
  LockQueueBcbLock,
  LockQueueMmNonPagedPoolLock,
  LockQueueUnusedSpare16,
  LockQueueTimerTableLock,
  LockQueueMaximumLock = LockQueueTimerTableLock + LOCK_QUEUE_TIMER_TABLE_LOCKS
} KSPIN_LOCK_QUEUE_NUMBER, *PKSPIN_LOCK_QUEUE_NUMBER;

#endif /* defined(_AMD64_) */

typedef VOID
(NTAPI KDEFERRED_ROUTINE)(
  IN struct _KDPC *Dpc,
  IN PVOID DeferredContext OPTIONAL,
  IN PVOID SystemArgument1 OPTIONAL,
  IN PVOID SystemArgument2 OPTIONAL);
typedef KDEFERRED_ROUTINE *PKDEFERRED_ROUTINE;

typedef enum _KDPC_IMPORTANCE {
  LowImportance,
  MediumImportance,
  HighImportance,
  MediumHighImportance
} KDPC_IMPORTANCE;

typedef struct _KDPC {
  UCHAR Type;
  UCHAR Importance;
  volatile USHORT Number;
  LIST_ENTRY DpcListEntry;
  PKDEFERRED_ROUTINE DeferredRoutine;
  PVOID DeferredContext;
  PVOID SystemArgument1;
  PVOID SystemArgument2;
  volatile PVOID DpcData;
} KDPC, *PKDPC, *RESTRICTED_POINTER PRKDPC;

typedef struct _KDPC_WATCHDOG_INFORMATION {
  ULONG DpcTimeLimit;
  ULONG DpcTimeCount;
  ULONG DpcWatchdogLimit;
  ULONG DpcWatchdogCount;
  ULONG Reserved;
} KDPC_WATCHDOG_INFORMATION, *PKDPC_WATCHDOG_INFORMATION;

typedef struct _KDEVICE_QUEUE {
  CSHORT Type;
  CSHORT Size;
  LIST_ENTRY DeviceListHead;
  KSPIN_LOCK Lock;
# if defined(_AMD64_)
  _ANONYMOUS_UNION union {
    BOOLEAN Busy;
    _ANONYMOUS_STRUCT struct {
      LONG64 Reserved:8;
      LONG64 Hint:56;
    } DUMMYSTRUCTNAME;
  } DUMMYUNIONNAME;
# else
  BOOLEAN Busy;
# endif
} KDEVICE_QUEUE, *PKDEVICE_QUEUE, *RESTRICTED_POINTER PRKDEVICE_QUEUE;

#define TIMER_EXPIRED_INDEX_BITS        6
#define TIMER_PROCESSOR_INDEX_BITS      5

typedef struct _DISPATCHER_HEADER {
  _ANONYMOUS_UNION union {
    _ANONYMOUS_STRUCT struct {
      UCHAR Type;
      _ANONYMOUS_UNION union {
        _ANONYMOUS_UNION union {
          UCHAR TimerControlFlags;
          _ANONYMOUS_STRUCT struct {
            UCHAR Absolute:1;
            UCHAR Coalescable:1;
            UCHAR KeepShifting:1;
            UCHAR EncodedTolerableDelay:5;
          } DUMMYSTRUCTNAME;
        } DUMMYUNIONNAME;
        UCHAR Abandoned;
#if (NTDDI_VERSION < NTDDI_WIN7)
        UCHAR NpxIrql;
#endif
        BOOLEAN Signalling;
      } DUMMYUNIONNAME;
      _ANONYMOUS_UNION union {
        _ANONYMOUS_UNION union {
          UCHAR ThreadControlFlags;
          _ANONYMOUS_STRUCT struct {
            UCHAR CpuThrottled:1;
            UCHAR CycleProfiling:1;
            UCHAR CounterProfiling:1;
            UCHAR Reserved:5;
          } DUMMYSTRUCTNAME;
        } DUMMYUNIONNAME;
        UCHAR Size;
        UCHAR Hand;
      } DUMMYUNIONNAME2;
      _ANONYMOUS_UNION union {
#if (NTDDI_VERSION >= NTDDI_WIN7)
        _ANONYMOUS_UNION union {
          UCHAR TimerMiscFlags;
          _ANONYMOUS_STRUCT struct {
#if !defined(_X86_)
            UCHAR Index:TIMER_EXPIRED_INDEX_BITS;
#else
            UCHAR Index:1;
            UCHAR Processor:TIMER_PROCESSOR_INDEX_BITS;
#endif
            UCHAR Inserted:1;
            volatile UCHAR Expired:1;
          } DUMMYSTRUCTNAME;
        } DUMMYUNIONNAME;
#else
        /* Pre Win7 compatibility fix to latest WDK */
        UCHAR Inserted;
#endif
        _ANONYMOUS_UNION union {
          BOOLEAN DebugActive;
          _ANONYMOUS_STRUCT struct {
            BOOLEAN ActiveDR7:1;
            BOOLEAN Instrumented:1;
            BOOLEAN Reserved2:4;
            BOOLEAN UmsScheduled:1;
            BOOLEAN UmsPrimary:1;
          } DUMMYSTRUCTNAME;
        } DUMMYUNIONNAME; /* should probably be DUMMYUNIONNAME2, but this is what WDK says */
        BOOLEAN DpcActive;
      } DUMMYUNIONNAME3;
    } DUMMYSTRUCTNAME;
    volatile LONG Lock;
  } DUMMYUNIONNAME;
  LONG SignalState;
  LIST_ENTRY WaitListHead;
} DISPATCHER_HEADER, *PDISPATCHER_HEADER;

typedef struct _KEVENT {
  DISPATCHER_HEADER Header;
} KEVENT, *PKEVENT, *RESTRICTED_POINTER PRKEVENT;

typedef struct _KSEMAPHORE {
  DISPATCHER_HEADER Header;
  LONG Limit;
} KSEMAPHORE, *PKSEMAPHORE, *RESTRICTED_POINTER PRKSEMAPHORE;

#define KSEMAPHORE_ACTUAL_LENGTH (FIELD_OFFSET(KSEMAPHORE, Limit) + sizeof(LONG))

typedef struct _KGATE {
  DISPATCHER_HEADER Header;
} KGATE, *PKGATE, *RESTRICTED_POINTER PRKGATE;

typedef struct _KGUARDED_MUTEX {
  volatile LONG Count;
  PKTHREAD Owner;
  ULONG Contention;
  KGATE Gate;
  _ANONYMOUS_UNION union {
    _ANONYMOUS_STRUCT struct {
      SHORT KernelApcDisable;
      SHORT SpecialApcDisable;
    } DUMMYSTRUCTNAME;
    ULONG CombinedApcDisable;
  } DUMMYUNIONNAME;
} KGUARDED_MUTEX, *PKGUARDED_MUTEX;

typedef struct _KMUTANT {
  DISPATCHER_HEADER Header;
  LIST_ENTRY MutantListEntry;
  struct _KTHREAD *RESTRICTED_POINTER OwnerThread;
  BOOLEAN Abandoned;
  UCHAR ApcDisable;
} KMUTANT, *PKMUTANT, *RESTRICTED_POINTER PRKMUTANT, KMUTEX, *PKMUTEX, *RESTRICTED_POINTER PRKMUTEX;

#define TIMER_TABLE_SIZE 512
#define TIMER_TABLE_SHIFT 9

typedef struct _KTIMER {
  DISPATCHER_HEADER Header;
  ULARGE_INTEGER DueTime;
  LIST_ENTRY TimerListEntry;
  struct _KDPC *Dpc;
# if !defined(_X86_)
  ULONG Processor;
# endif
  ULONG Period;
} KTIMER, *PKTIMER, *RESTRICTED_POINTER PRKTIMER;

typedef enum _LOCK_OPERATION {
  IoReadAccess,
  IoWriteAccess,
  IoModifyAccess
} LOCK_OPERATION;

#define KTIMER_ACTUAL_LENGTH (FIELD_OFFSET(KTIMER, Period) + sizeof(LONG))

typedef BOOLEAN
(NTAPI *PKSYNCHRONIZE_ROUTINE)(
  IN PVOID SynchronizeContext);

typedef enum _POOL_TYPE {
  NonPagedPool,
  PagedPool,
  NonPagedPoolMustSucceed,
  DontUseThisType,
  NonPagedPoolCacheAligned,
  PagedPoolCacheAligned,
  NonPagedPoolCacheAlignedMustS,
  MaxPoolType,
  NonPagedPoolSession = 32,
  PagedPoolSession,
  NonPagedPoolMustSucceedSession,
  DontUseThisTypeSession,
  NonPagedPoolCacheAlignedSession,
  PagedPoolCacheAlignedSession,
  NonPagedPoolCacheAlignedMustSSession
} POOL_TYPE;

typedef enum _ALTERNATIVE_ARCHITECTURE_TYPE {
  StandardDesign,
  NEC98x86,
  EndAlternatives
} ALTERNATIVE_ARCHITECTURE_TYPE;

#ifndef _X86_

#ifndef IsNEC_98
#define IsNEC_98 (FALSE)
#endif

#ifndef IsNotNEC_98
#define IsNotNEC_98 (TRUE)
#endif

#ifndef SetNEC_98
#define SetNEC_98
#endif

#ifndef SetNotNEC_98
#define SetNotNEC_98
#endif

#endif

typedef struct _KSYSTEM_TIME {
  ULONG LowPart;
  LONG High1Time;
  LONG High2Time;
} KSYSTEM_TIME, *PKSYSTEM_TIME;

typedef struct DECLSPEC_ALIGN(16) _M128A {
  ULONGLONG Low;
  LONGLONG High;
} M128A, *PM128A;

typedef struct DECLSPEC_ALIGN(16) _XSAVE_FORMAT {
  USHORT ControlWord;
  USHORT StatusWord;
  UCHAR TagWord;
  UCHAR Reserved1;
  USHORT ErrorOpcode;
  ULONG ErrorOffset;
  USHORT ErrorSelector;
  USHORT Reserved2;
  ULONG DataOffset;
  USHORT DataSelector;
  USHORT Reserved3;
  ULONG MxCsr;
  ULONG MxCsr_Mask;
  M128A FloatRegisters[8];
#if defined(_WIN64)
  M128A XmmRegisters[16];
  UCHAR Reserved4[96];
#else
  M128A XmmRegisters[8];
  UCHAR Reserved4[192];
  ULONG StackControl[7];
  ULONG Cr0NpxState;
#endif
} XSAVE_FORMAT, *PXSAVE_FORMAT;

typedef struct DECLSPEC_ALIGN(8) _XSAVE_AREA_HEADER {
  ULONG64 Mask;
  ULONG64 Reserved[7];
} XSAVE_AREA_HEADER, *PXSAVE_AREA_HEADER;

typedef struct DECLSPEC_ALIGN(16) _XSAVE_AREA {
  XSAVE_FORMAT LegacyState;
  XSAVE_AREA_HEADER Header;
} XSAVE_AREA, *PXSAVE_AREA;

typedef struct _XSTATE_CONTEXT {
  ULONG64 Mask;
  ULONG Length;
  ULONG Reserved1;
  PXSAVE_AREA Area;
#if defined(_X86_)
  ULONG Reserved2;
#endif
  PVOID Buffer;
#if defined(_X86_)
  ULONG Reserved3;
#endif
} XSTATE_CONTEXT, *PXSTATE_CONTEXT;

typedef struct _XSTATE_SAVE {
#if defined(_AMD64_)
  struct _XSTATE_SAVE* Prev;
  struct _KTHREAD* Thread;
  UCHAR Level;
  XSTATE_CONTEXT XStateContext;
#elif defined(_IA64_)
  ULONG Dummy;
#elif defined(_X86_)
  _ANONYMOUS_UNION union {
    _ANONYMOUS_STRUCT struct {
      LONG64 Reserved1;
      ULONG Reserved2;
      struct _XSTATE_SAVE* Prev;
      PXSAVE_AREA Reserved3;
      struct _KTHREAD* Thread;
      PVOID Reserved4;
      UCHAR Level;
    } DUMMYSTRUCTNAME;
    XSTATE_CONTEXT XStateContext;
  } DUMMYUNIONNAME;
#endif
} XSTATE_SAVE, *PXSTATE_SAVE;

#ifdef _X86_

#define MAXIMUM_SUPPORTED_EXTENSION  512

#if !defined(__midl) && !defined(MIDL_PASS)
C_ASSERT(sizeof(XSAVE_FORMAT) == MAXIMUM_SUPPORTED_EXTENSION);
#endif

#endif /* _X86_ */

#define XSAVE_ALIGN                    64
#define MINIMAL_XSTATE_AREA_LENGTH     sizeof(XSAVE_AREA)

#if !defined(__midl) && !defined(MIDL_PASS)
C_ASSERT((sizeof(XSAVE_FORMAT) & (XSAVE_ALIGN - 1)) == 0);
C_ASSERT((FIELD_OFFSET(XSAVE_AREA, Header) & (XSAVE_ALIGN - 1)) == 0);
C_ASSERT(MINIMAL_XSTATE_AREA_LENGTH == 512 + 64);
#endif

typedef struct _CONTEXT_CHUNK {
  LONG Offset;
  ULONG Length;
} CONTEXT_CHUNK, *PCONTEXT_CHUNK;

typedef struct _CONTEXT_EX {
  CONTEXT_CHUNK All;
  CONTEXT_CHUNK Legacy;
  CONTEXT_CHUNK XState;
} CONTEXT_EX, *PCONTEXT_EX;

#define CONTEXT_EX_LENGTH         ALIGN_UP_BY(sizeof(CONTEXT_EX), STACK_ALIGN)

#if (NTDDI_VERSION >= NTDDI_VISTA)
extern NTSYSAPI volatile CCHAR KeNumberProcessors;
#elif (NTDDI_VERSION >= NTDDI_WINXP)
extern NTSYSAPI CCHAR KeNumberProcessors;
#else
extern PCCHAR KeNumberProcessors;
#endif


/******************************************************************************
 *                         Memory manager Types                               *
 ******************************************************************************/

#if (NTDDI_VERSION >= NTDDI_WIN2K)
typedef ULONG NODE_REQUIREMENT;
#define MM_ANY_NODE_OK                           0x80000000
#endif

#define MM_DONT_ZERO_ALLOCATION                  0x00000001
#define MM_ALLOCATE_FROM_LOCAL_NODE_ONLY         0x00000002
#define MM_ALLOCATE_FULLY_REQUIRED               0x00000004
#define MM_ALLOCATE_NO_WAIT                      0x00000008
#define MM_ALLOCATE_PREFER_CONTIGUOUS            0x00000010
#define MM_ALLOCATE_REQUIRE_CONTIGUOUS_CHUNKS    0x00000020

#define MDL_MAPPED_TO_SYSTEM_VA     0x0001
#define MDL_PAGES_LOCKED            0x0002
#define MDL_SOURCE_IS_NONPAGED_POOL 0x0004
#define MDL_ALLOCATED_FIXED_SIZE    0x0008
#define MDL_PARTIAL                 0x0010
#define MDL_PARTIAL_HAS_BEEN_MAPPED 0x0020
#define MDL_IO_PAGE_READ            0x0040
#define MDL_WRITE_OPERATION         0x0080
#define MDL_PARENT_MAPPED_SYSTEM_VA 0x0100
#define MDL_FREE_EXTRA_PTES         0x0200
#define MDL_DESCRIBES_AWE           0x0400
#define MDL_IO_SPACE                0x0800
#define MDL_NETWORK_HEADER          0x1000
#define MDL_MAPPING_CAN_FAIL        0x2000
#define MDL_ALLOCATED_MUST_SUCCEED  0x4000
#define MDL_INTERNAL                0x8000

#define MDL_MAPPING_FLAGS (MDL_MAPPED_TO_SYSTEM_VA     | \
                           MDL_PAGES_LOCKED            | \
                           MDL_SOURCE_IS_NONPAGED_POOL | \
                           MDL_PARTIAL_HAS_BEEN_MAPPED | \
                           MDL_PARENT_MAPPED_SYSTEM_VA | \
                           MDL_SYSTEM_VA               | \
                           MDL_IO_SPACE)

#define FLUSH_MULTIPLE_MAXIMUM       32

/* Section access rights */
#define SECTION_QUERY                0x0001
#define SECTION_MAP_WRITE            0x0002
#define SECTION_MAP_READ             0x0004
#define SECTION_MAP_EXECUTE          0x0008
#define SECTION_EXTEND_SIZE          0x0010
#define SECTION_MAP_EXECUTE_EXPLICIT 0x0020

#define SECTION_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED|SECTION_QUERY| \
                            SECTION_MAP_WRITE |                     \
                            SECTION_MAP_READ |                      \
                            SECTION_MAP_EXECUTE |                   \
                            SECTION_EXTEND_SIZE)

#define SESSION_QUERY_ACCESS         0x0001
#define SESSION_MODIFY_ACCESS        0x0002

#define SESSION_ALL_ACCESS (STANDARD_RIGHTS_REQUIRED |  \
                            SESSION_QUERY_ACCESS     |  \
                            SESSION_MODIFY_ACCESS)

#define SEGMENT_ALL_ACCESS SECTION_ALL_ACCESS

#define PAGE_NOACCESS          0x01
#define PAGE_READONLY          0x02
#define PAGE_READWRITE         0x04
#define PAGE_WRITECOPY         0x08
#define PAGE_EXECUTE           0x10
#define PAGE_EXECUTE_READ      0x20
#define PAGE_EXECUTE_READWRITE 0x40
#define PAGE_EXECUTE_WRITECOPY 0x80
#define PAGE_GUARD            0x100
#define PAGE_NOCACHE          0x200
#define PAGE_WRITECOMBINE     0x400

#define MEM_COMMIT           0x1000
#define MEM_RESERVE          0x2000
#define MEM_DECOMMIT         0x4000
#define MEM_RELEASE          0x8000
#define MEM_FREE            0x10000
#define MEM_PRIVATE         0x20000
#define MEM_MAPPED          0x40000
#define MEM_RESET           0x80000
#define MEM_TOP_DOWN       0x100000
#define MEM_LARGE_PAGES  0x20000000
#define MEM_4MB_PAGES    0x80000000

#define SEC_RESERVE       0x4000000
#define SEC_COMMIT        0x8000000
#define SEC_LARGE_PAGES  0x80000000

/* Section map options */
typedef enum _SECTION_INHERIT {
  ViewShare = 1,
  ViewUnmap = 2
} SECTION_INHERIT;

typedef ULONG PFN_COUNT;
typedef LONG_PTR SPFN_NUMBER, *PSPFN_NUMBER;
typedef ULONG_PTR PFN_NUMBER, *PPFN_NUMBER;

typedef struct _MDL {
  struct _MDL *Next;
  CSHORT Size;
  CSHORT MdlFlags;
  struct _EPROCESS *Process;
  PVOID MappedSystemVa;
  PVOID StartVa;
  ULONG ByteCount;
  ULONG ByteOffset;
} MDL, *PMDL;
typedef MDL *PMDLX;

typedef enum _MEMORY_CACHING_TYPE_ORIG {
  MmFrameBufferCached = 2
} MEMORY_CACHING_TYPE_ORIG;

typedef enum _MEMORY_CACHING_TYPE {
  MmNonCached = FALSE,
  MmCached = TRUE,
  MmWriteCombined = MmFrameBufferCached,
  MmHardwareCoherentCached,
  MmNonCachedUnordered,
  MmUSWCCached,
  MmMaximumCacheType
} MEMORY_CACHING_TYPE;

typedef enum _MM_PAGE_PRIORITY {
  LowPagePriority,
  NormalPagePriority = 16,
  HighPagePriority = 32
} MM_PAGE_PRIORITY;

typedef enum _MM_SYSTEM_SIZE {
  MmSmallSystem,
  MmMediumSystem,
  MmLargeSystem
} MM_SYSTEMSIZE;

extern NTKERNELAPI BOOLEAN Mm64BitPhysicalAddress;
extern PVOID MmBadPointer;


/******************************************************************************
 *                            Executive Types                                 *
 ******************************************************************************/
#define EX_RUNDOWN_ACTIVE                 0x1
#define EX_RUNDOWN_COUNT_SHIFT            0x1
#define EX_RUNDOWN_COUNT_INC              (1 << EX_RUNDOWN_COUNT_SHIFT)

typedef struct _FAST_MUTEX {
  volatile LONG Count;
  PKTHREAD Owner;
  ULONG Contention;
  KEVENT Event;
  ULONG OldIrql;
} FAST_MUTEX, *PFAST_MUTEX;

typedef enum _SUITE_TYPE {
  SmallBusiness,
  Enterprise,
  BackOffice,
  CommunicationServer,
  TerminalServer,
  SmallBusinessRestricted,
  EmbeddedNT,
  DataCenter,
  SingleUserTS,
  Personal,
  Blade,
  EmbeddedRestricted,
  SecurityAppliance,
  StorageServer,
  ComputeServer,
  WHServer,
  MaxSuiteType
} SUITE_TYPE;

typedef enum _EX_POOL_PRIORITY {
  LowPoolPriority,
  LowPoolPrioritySpecialPoolOverrun = 8,
  LowPoolPrioritySpecialPoolUnderrun = 9,
  NormalPoolPriority = 16,
  NormalPoolPrioritySpecialPoolOverrun = 24,
  NormalPoolPrioritySpecialPoolUnderrun = 25,
  HighPoolPriority = 32,
  HighPoolPrioritySpecialPoolOverrun = 40,
  HighPoolPrioritySpecialPoolUnderrun = 41
} EX_POOL_PRIORITY;

#if !defined(_WIN64) && (defined(_NTDDK_) || defined(_NTIFS_) || defined(_NDIS_))
#define LOOKASIDE_ALIGN
#else
#define LOOKASIDE_ALIGN DECLSPEC_CACHEALIGN
#endif

typedef struct _LOOKASIDE_LIST_EX *PLOOKASIDE_LIST_EX;

typedef PVOID
(NTAPI *PALLOCATE_FUNCTION)(
  IN POOL_TYPE PoolType,
  IN SIZE_T NumberOfBytes,
  IN ULONG Tag);

typedef PVOID
(NTAPI *PALLOCATE_FUNCTION_EX)(
  IN POOL_TYPE PoolType,
  IN SIZE_T NumberOfBytes,
  IN ULONG Tag,
  IN OUT PLOOKASIDE_LIST_EX Lookaside);

typedef VOID
(NTAPI *PFREE_FUNCTION)(
  IN PVOID Buffer);

typedef VOID
(NTAPI *PFREE_FUNCTION_EX)(
  IN PVOID Buffer,
  IN OUT PLOOKASIDE_LIST_EX Lookaside);

typedef VOID
(NTAPI CALLBACK_FUNCTION)(
  IN PVOID CallbackContext OPTIONAL,
  IN PVOID Argument1 OPTIONAL,
  IN PVOID Argument2 OPTIONAL);
typedef CALLBACK_FUNCTION *PCALLBACK_FUNCTION;

#define GENERAL_LOOKASIDE_LAYOUT                \
    _ANONYMOUS_UNION union {                    \
        SLIST_HEADER ListHead;                  \
        SINGLE_LIST_ENTRY SingleListHead;       \
    } DUMMYUNIONNAME;                           \
    USHORT Depth;                               \
    USHORT MaximumDepth;                        \
    ULONG TotalAllocates;                       \
    _ANONYMOUS_UNION union {                    \
        ULONG AllocateMisses;                   \
        ULONG AllocateHits;                     \
    } DUMMYUNIONNAME2;                          \
    ULONG TotalFrees;                           \
    _ANONYMOUS_UNION union {                    \
        ULONG FreeMisses;                       \
        ULONG FreeHits;                         \
    } DUMMYUNIONNAME3;                          \
    POOL_TYPE Type;                             \
    ULONG Tag;                                  \
    ULONG Size;                                 \
    _ANONYMOUS_UNION union {                    \
        PALLOCATE_FUNCTION_EX AllocateEx;       \
        PALLOCATE_FUNCTION Allocate;            \
    } DUMMYUNIONNAME4;                          \
    _ANONYMOUS_UNION union {                    \
        PFREE_FUNCTION_EX FreeEx;               \
        PFREE_FUNCTION Free;                    \
    } DUMMYUNIONNAME5;                          \
    LIST_ENTRY ListEntry;                       \
    ULONG LastTotalAllocates;                   \
    _ANONYMOUS_UNION union {                    \
        ULONG LastAllocateMisses;               \
        ULONG LastAllocateHits;                 \
    } DUMMYUNIONNAME6;                          \
    ULONG Future[2];

typedef struct LOOKASIDE_ALIGN _GENERAL_LOOKASIDE {
  GENERAL_LOOKASIDE_LAYOUT
} GENERAL_LOOKASIDE, *PGENERAL_LOOKASIDE;

typedef struct _GENERAL_LOOKASIDE_POOL {
  GENERAL_LOOKASIDE_LAYOUT
} GENERAL_LOOKASIDE_POOL, *PGENERAL_LOOKASIDE_POOL;

#define LOOKASIDE_CHECK(f)  \
    C_ASSERT(FIELD_OFFSET(GENERAL_LOOKASIDE,f) == FIELD_OFFSET(GENERAL_LOOKASIDE_POOL,f))

LOOKASIDE_CHECK(TotalFrees);
LOOKASIDE_CHECK(Tag);
LOOKASIDE_CHECK(Future);

typedef struct _PAGED_LOOKASIDE_LIST {
  GENERAL_LOOKASIDE L;
#if !defined(_AMD64_) && !defined(_IA64_)
  FAST_MUTEX Lock__ObsoleteButDoNotDelete;
#endif
} PAGED_LOOKASIDE_LIST, *PPAGED_LOOKASIDE_LIST;

typedef struct LOOKASIDE_ALIGN _NPAGED_LOOKASIDE_LIST {
  GENERAL_LOOKASIDE L;
#if !defined(_AMD64_) && !defined(_IA64_)
  KSPIN_LOCK Lock__ObsoleteButDoNotDelete;
#endif
} NPAGED_LOOKASIDE_LIST, *PNPAGED_LOOKASIDE_LIST;

#define LOOKASIDE_MINIMUM_BLOCK_SIZE (RTL_SIZEOF_THROUGH_FIELD (SLIST_ENTRY, Next))

typedef struct _LOOKASIDE_LIST_EX {
  GENERAL_LOOKASIDE_POOL L;
} LOOKASIDE_LIST_EX;

#if (NTDDI_VERSION >= NTDDI_VISTA)

#define EX_LOOKASIDE_LIST_EX_FLAGS_RAISE_ON_FAIL 0x00000001UL
#define EX_LOOKASIDE_LIST_EX_FLAGS_FAIL_NO_RAISE 0x00000002UL

#define EX_MAXIMUM_LOOKASIDE_DEPTH_BASE          256
#define EX_MAXIMUM_LOOKASIDE_DEPTH_LIMIT         1024

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

typedef struct _EX_RUNDOWN_REF {
  _ANONYMOUS_UNION union {
    volatile ULONG_PTR Count;
    volatile PVOID Ptr;
  } DUMMYUNIONNAME;
} EX_RUNDOWN_REF, *PEX_RUNDOWN_REF;

typedef struct _EX_RUNDOWN_REF_CACHE_AWARE *PEX_RUNDOWN_REF_CACHE_AWARE;

typedef enum _WORK_QUEUE_TYPE {
  CriticalWorkQueue,
  DelayedWorkQueue,
  HyperCriticalWorkQueue,
  MaximumWorkQueue
} WORK_QUEUE_TYPE;

typedef VOID
(NTAPI WORKER_THREAD_ROUTINE)(
  IN PVOID Parameter);
typedef WORKER_THREAD_ROUTINE *PWORKER_THREAD_ROUTINE;

typedef struct _WORK_QUEUE_ITEM {
  LIST_ENTRY List;
  PWORKER_THREAD_ROUTINE WorkerRoutine;
  volatile PVOID Parameter;
} WORK_QUEUE_ITEM, *PWORK_QUEUE_ITEM;

typedef ULONG_PTR ERESOURCE_THREAD, *PERESOURCE_THREAD;

typedef struct _OWNER_ENTRY {
  ERESOURCE_THREAD OwnerThread;
  _ANONYMOUS_UNION union {
    _ANONYMOUS_STRUCT struct {
      ULONG IoPriorityBoosted:1;
      ULONG OwnerReferenced:1;
      ULONG OwnerCount:30;
    } DUMMYSTRUCTNAME;
    ULONG TableSize;
  } DUMMYUNIONNAME;
} OWNER_ENTRY, *POWNER_ENTRY;

typedef struct _ERESOURCE {
  LIST_ENTRY SystemResourcesList;
  POWNER_ENTRY OwnerTable;
  SHORT ActiveCount;
  USHORT Flag;
  volatile PKSEMAPHORE SharedWaiters;
  volatile PKEVENT ExclusiveWaiters;
  OWNER_ENTRY OwnerEntry;
  ULONG ActiveEntries;
  ULONG ContentionCount;
  ULONG NumberOfSharedWaiters;
  ULONG NumberOfExclusiveWaiters;
#if defined(_WIN64)
  PVOID Reserved2;
#endif
  _ANONYMOUS_UNION union {
    PVOID Address;
    ULONG_PTR CreatorBackTraceIndex;
  } DUMMYUNIONNAME;
  KSPIN_LOCK SpinLock;
} ERESOURCE, *PERESOURCE;

/* ERESOURCE.Flag */
#define ResourceNeverExclusive            0x0010
#define ResourceReleaseByOtherThread      0x0020
#define ResourceOwnedExclusive            0x0080

#define RESOURCE_HASH_TABLE_SIZE          64

typedef struct _RESOURCE_HASH_ENTRY {
  LIST_ENTRY ListEntry;
  PVOID Address;
  ULONG ContentionCount;
  ULONG Number;
} RESOURCE_HASH_ENTRY, *PRESOURCE_HASH_ENTRY;

typedef struct _RESOURCE_PERFORMANCE_DATA {
  ULONG ActiveResourceCount;
  ULONG TotalResourceCount;
  ULONG ExclusiveAcquire;
  ULONG SharedFirstLevel;
  ULONG SharedSecondLevel;
  ULONG StarveFirstLevel;
  ULONG StarveSecondLevel;
  ULONG WaitForExclusive;
  ULONG OwnerTableExpands;
  ULONG MaximumTableExpand;
  LIST_ENTRY HashTable[RESOURCE_HASH_TABLE_SIZE];
} RESOURCE_PERFORMANCE_DATA, *PRESOURCE_PERFORMANCE_DATA;

/* Global debug flag */
#if DEVL
extern ULONG NtGlobalFlag;
#define IF_NTOS_DEBUG(FlagName) if (NtGlobalFlag & (FLG_##FlagName))
#else
#define IF_NTOS_DEBUG(FlagName) if(FALSE)
#endif

/******************************************************************************
 *                            Security Manager Types                          *
 ******************************************************************************/

/* Simple types */
typedef PVOID PSECURITY_DESCRIPTOR;
typedef ULONG SECURITY_INFORMATION, *PSECURITY_INFORMATION;
typedef ULONG ACCESS_MASK, *PACCESS_MASK;
typedef PVOID PACCESS_TOKEN;
typedef PVOID PSID;

#define DELETE                           0x00010000L
#define READ_CONTROL                     0x00020000L
#define WRITE_DAC                        0x00040000L
#define WRITE_OWNER                      0x00080000L
#define SYNCHRONIZE                      0x00100000L
#define STANDARD_RIGHTS_REQUIRED         0x000F0000L
#define STANDARD_RIGHTS_READ             READ_CONTROL
#define STANDARD_RIGHTS_WRITE            READ_CONTROL
#define STANDARD_RIGHTS_EXECUTE          READ_CONTROL
#define STANDARD_RIGHTS_ALL              0x001F0000L
#define SPECIFIC_RIGHTS_ALL              0x0000FFFFL
#define ACCESS_SYSTEM_SECURITY           0x01000000L
#define MAXIMUM_ALLOWED                  0x02000000L
#define GENERIC_READ                     0x80000000L
#define GENERIC_WRITE                    0x40000000L
#define GENERIC_EXECUTE                  0x20000000L
#define GENERIC_ALL                      0x10000000L

typedef struct _GENERIC_MAPPING {
  ACCESS_MASK GenericRead;
  ACCESS_MASK GenericWrite;
  ACCESS_MASK GenericExecute;
  ACCESS_MASK GenericAll;
} GENERIC_MAPPING, *PGENERIC_MAPPING;

#define ACL_REVISION                      2
#define ACL_REVISION_DS                   4

#define ACL_REVISION1                     1
#define ACL_REVISION2                     2
#define ACL_REVISION3                     3
#define ACL_REVISION4                     4
#define MIN_ACL_REVISION                  ACL_REVISION2
#define MAX_ACL_REVISION                  ACL_REVISION4

typedef struct _ACL {
  UCHAR AclRevision;
  UCHAR Sbz1;
  USHORT AclSize;
  USHORT AceCount;
  USHORT Sbz2;
} ACL, *PACL;

/* Current security descriptor revision value */
#define SECURITY_DESCRIPTOR_REVISION     (1)
#define SECURITY_DESCRIPTOR_REVISION1    (1)

/* Privilege attributes */
#define SE_PRIVILEGE_ENABLED_BY_DEFAULT (0x00000001L)
#define SE_PRIVILEGE_ENABLED            (0x00000002L)
#define SE_PRIVILEGE_REMOVED            (0X00000004L)
#define SE_PRIVILEGE_USED_FOR_ACCESS    (0x80000000L)

#define SE_PRIVILEGE_VALID_ATTRIBUTES   (SE_PRIVILEGE_ENABLED_BY_DEFAULT | \
                                         SE_PRIVILEGE_ENABLED            | \
                                         SE_PRIVILEGE_REMOVED            | \
                                         SE_PRIVILEGE_USED_FOR_ACCESS)

#include <pshpack4.h>
typedef struct _LUID_AND_ATTRIBUTES {
  LUID Luid;
  ULONG Attributes;
} LUID_AND_ATTRIBUTES, *PLUID_AND_ATTRIBUTES;
#include <poppack.h>

typedef LUID_AND_ATTRIBUTES LUID_AND_ATTRIBUTES_ARRAY[ANYSIZE_ARRAY];
typedef LUID_AND_ATTRIBUTES_ARRAY *PLUID_AND_ATTRIBUTES_ARRAY;

/* Privilege sets */
#define PRIVILEGE_SET_ALL_NECESSARY (1)

typedef struct _PRIVILEGE_SET {
  ULONG PrivilegeCount;
  ULONG Control;
  LUID_AND_ATTRIBUTES Privilege[ANYSIZE_ARRAY];
} PRIVILEGE_SET,*PPRIVILEGE_SET;

typedef enum _SECURITY_IMPERSONATION_LEVEL {
  SecurityAnonymous,
  SecurityIdentification,
  SecurityImpersonation,
  SecurityDelegation
} SECURITY_IMPERSONATION_LEVEL, * PSECURITY_IMPERSONATION_LEVEL;

#define SECURITY_MAX_IMPERSONATION_LEVEL SecurityDelegation
#define SECURITY_MIN_IMPERSONATION_LEVEL SecurityAnonymous
#define DEFAULT_IMPERSONATION_LEVEL SecurityImpersonation
#define VALID_IMPERSONATION_LEVEL(Level) (((Level) >= SECURITY_MIN_IMPERSONATION_LEVEL) && ((Level) <= SECURITY_MAX_IMPERSONATION_LEVEL))

#define SECURITY_DYNAMIC_TRACKING (TRUE)
#define SECURITY_STATIC_TRACKING (FALSE)

typedef BOOLEAN SECURITY_CONTEXT_TRACKING_MODE, *PSECURITY_CONTEXT_TRACKING_MODE;

typedef struct _SECURITY_QUALITY_OF_SERVICE {
  ULONG Length;
  SECURITY_IMPERSONATION_LEVEL ImpersonationLevel;
  SECURITY_CONTEXT_TRACKING_MODE ContextTrackingMode;
  BOOLEAN EffectiveOnly;
} SECURITY_QUALITY_OF_SERVICE, *PSECURITY_QUALITY_OF_SERVICE;

typedef struct _SE_IMPERSONATION_STATE {
  PACCESS_TOKEN Token;
  BOOLEAN CopyOnOpen;
  BOOLEAN EffectiveOnly;
  SECURITY_IMPERSONATION_LEVEL Level;
} SE_IMPERSONATION_STATE, *PSE_IMPERSONATION_STATE;

#define OWNER_SECURITY_INFORMATION       (0x00000001L)
#define GROUP_SECURITY_INFORMATION       (0x00000002L)
#define DACL_SECURITY_INFORMATION        (0x00000004L)
#define SACL_SECURITY_INFORMATION        (0x00000008L)
#define LABEL_SECURITY_INFORMATION       (0x00000010L)

#define PROTECTED_DACL_SECURITY_INFORMATION     (0x80000000L)
#define PROTECTED_SACL_SECURITY_INFORMATION     (0x40000000L)
#define UNPROTECTED_DACL_SECURITY_INFORMATION   (0x20000000L)
#define UNPROTECTED_SACL_SECURITY_INFORMATION   (0x10000000L)

typedef enum _SECURITY_OPERATION_CODE {
  SetSecurityDescriptor,
  QuerySecurityDescriptor,
  DeleteSecurityDescriptor,
  AssignSecurityDescriptor
} SECURITY_OPERATION_CODE, *PSECURITY_OPERATION_CODE;

#define INITIAL_PRIVILEGE_COUNT           3

typedef struct _INITIAL_PRIVILEGE_SET {
  ULONG PrivilegeCount;
  ULONG Control;
  LUID_AND_ATTRIBUTES Privilege[INITIAL_PRIVILEGE_COUNT];
} INITIAL_PRIVILEGE_SET, * PINITIAL_PRIVILEGE_SET;

#define SE_MIN_WELL_KNOWN_PRIVILEGE         2
#define SE_CREATE_TOKEN_PRIVILEGE           2
#define SE_ASSIGNPRIMARYTOKEN_PRIVILEGE     3
#define SE_LOCK_MEMORY_PRIVILEGE            4
#define SE_INCREASE_QUOTA_PRIVILEGE         5
#define SE_MACHINE_ACCOUNT_PRIVILEGE        6
#define SE_TCB_PRIVILEGE                    7
#define SE_SECURITY_PRIVILEGE               8
#define SE_TAKE_OWNERSHIP_PRIVILEGE         9
#define SE_LOAD_DRIVER_PRIVILEGE            10
#define SE_SYSTEM_PROFILE_PRIVILEGE         11
#define SE_SYSTEMTIME_PRIVILEGE             12
#define SE_PROF_SINGLE_PROCESS_PRIVILEGE    13
#define SE_INC_BASE_PRIORITY_PRIVILEGE      14
#define SE_CREATE_PAGEFILE_PRIVILEGE        15
#define SE_CREATE_PERMANENT_PRIVILEGE       16
#define SE_BACKUP_PRIVILEGE                 17
#define SE_RESTORE_PRIVILEGE                18
#define SE_SHUTDOWN_PRIVILEGE               19
#define SE_DEBUG_PRIVILEGE                  20
#define SE_AUDIT_PRIVILEGE                  21
#define SE_SYSTEM_ENVIRONMENT_PRIVILEGE     22
#define SE_CHANGE_NOTIFY_PRIVILEGE          23
#define SE_REMOTE_SHUTDOWN_PRIVILEGE        24
#define SE_UNDOCK_PRIVILEGE                 25
#define SE_SYNC_AGENT_PRIVILEGE             26
#define SE_ENABLE_DELEGATION_PRIVILEGE      27
#define SE_MANAGE_VOLUME_PRIVILEGE          28
#define SE_IMPERSONATE_PRIVILEGE            29
#define SE_CREATE_GLOBAL_PRIVILEGE          30
#define SE_TRUSTED_CREDMAN_ACCESS_PRIVILEGE 31
#define SE_RELABEL_PRIVILEGE                32
#define SE_INC_WORKING_SET_PRIVILEGE        33
#define SE_TIME_ZONE_PRIVILEGE              34
#define SE_CREATE_SYMBOLIC_LINK_PRIVILEGE   35
#define SE_MAX_WELL_KNOWN_PRIVILEGE         SE_CREATE_SYMBOLIC_LINK_PRIVILEGE

typedef struct _SECURITY_SUBJECT_CONTEXT {
  PACCESS_TOKEN ClientToken;
  SECURITY_IMPERSONATION_LEVEL ImpersonationLevel;
  PACCESS_TOKEN PrimaryToken;
  PVOID ProcessAuditId;
} SECURITY_SUBJECT_CONTEXT, *PSECURITY_SUBJECT_CONTEXT;

typedef struct _ACCESS_STATE {
  LUID OperationID;
  BOOLEAN SecurityEvaluated;
  BOOLEAN GenerateAudit;
  BOOLEAN GenerateOnClose;
  BOOLEAN PrivilegesAllocated;
  ULONG Flags;
  ACCESS_MASK RemainingDesiredAccess;
  ACCESS_MASK PreviouslyGrantedAccess;
  ACCESS_MASK OriginalDesiredAccess;
  SECURITY_SUBJECT_CONTEXT SubjectSecurityContext;
  PSECURITY_DESCRIPTOR SecurityDescriptor;
  PVOID AuxData;
  union {
    INITIAL_PRIVILEGE_SET InitialPrivilegeSet;
    PRIVILEGE_SET PrivilegeSet;
  } Privileges;
  BOOLEAN AuditPrivileges;
  UNICODE_STRING ObjectName;
  UNICODE_STRING ObjectTypeName;
} ACCESS_STATE, *PACCESS_STATE;

typedef VOID
(NTAPI *PNTFS_DEREF_EXPORTED_SECURITY_DESCRIPTOR)(
  IN PVOID Vcb,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor);

#ifndef _NTLSA_IFS_

#ifndef _NTLSA_AUDIT_
#define _NTLSA_AUDIT_

#define SE_MAX_AUDIT_PARAMETERS 32
#define SE_MAX_GENERIC_AUDIT_PARAMETERS 28

#define SE_ADT_OBJECT_ONLY 0x1

#define SE_ADT_PARAMETERS_SELF_RELATIVE    0x00000001
#define SE_ADT_PARAMETERS_SEND_TO_LSA      0x00000002
#define SE_ADT_PARAMETER_EXTENSIBLE_AUDIT  0x00000004
#define SE_ADT_PARAMETER_GENERIC_AUDIT     0x00000008
#define SE_ADT_PARAMETER_WRITE_SYNCHRONOUS 0x00000010

#define LSAP_SE_ADT_PARAMETER_ARRAY_TRUE_SIZE(Parameters) \
  ( sizeof(SE_ADT_PARAMETER_ARRAY) - sizeof(SE_ADT_PARAMETER_ARRAY_ENTRY) * \
    (SE_MAX_AUDIT_PARAMETERS - Parameters->ParameterCount) )

typedef enum _SE_ADT_PARAMETER_TYPE {
  SeAdtParmTypeNone = 0,
  SeAdtParmTypeString,
  SeAdtParmTypeFileSpec,
  SeAdtParmTypeUlong,
  SeAdtParmTypeSid,
  SeAdtParmTypeLogonId,
  SeAdtParmTypeNoLogonId,
  SeAdtParmTypeAccessMask,
  SeAdtParmTypePrivs,
  SeAdtParmTypeObjectTypes,
  SeAdtParmTypeHexUlong,
  SeAdtParmTypePtr,
  SeAdtParmTypeTime,
  SeAdtParmTypeGuid,
  SeAdtParmTypeLuid,
  SeAdtParmTypeHexInt64,
  SeAdtParmTypeStringList,
  SeAdtParmTypeSidList,
  SeAdtParmTypeDuration,
  SeAdtParmTypeUserAccountControl,
  SeAdtParmTypeNoUac,
  SeAdtParmTypeMessage,
  SeAdtParmTypeDateTime,
  SeAdtParmTypeSockAddr,
  SeAdtParmTypeSD,
  SeAdtParmTypeLogonHours,
  SeAdtParmTypeLogonIdNoSid,
  SeAdtParmTypeUlongNoConv,
  SeAdtParmTypeSockAddrNoPort,
  SeAdtParmTypeAccessReason
} SE_ADT_PARAMETER_TYPE, *PSE_ADT_PARAMETER_TYPE;

typedef struct _SE_ADT_OBJECT_TYPE {
  GUID ObjectType;
  USHORT Flags;
  USHORT Level;
  ACCESS_MASK AccessMask;
} SE_ADT_OBJECT_TYPE, *PSE_ADT_OBJECT_TYPE;

typedef struct _SE_ADT_PARAMETER_ARRAY_ENTRY {
  SE_ADT_PARAMETER_TYPE Type;
  ULONG Length;
  ULONG_PTR Data[2];
  PVOID Address;
} SE_ADT_PARAMETER_ARRAY_ENTRY, *PSE_ADT_PARAMETER_ARRAY_ENTRY;

typedef struct _SE_ADT_ACCESS_REASON {
  ACCESS_MASK AccessMask;
  ULONG AccessReasons[32];
  ULONG ObjectTypeIndex;
  ULONG AccessGranted;
  PSECURITY_DESCRIPTOR SecurityDescriptor;
} SE_ADT_ACCESS_REASON, *PSE_ADT_ACCESS_REASON;

typedef struct _SE_ADT_PARAMETER_ARRAY {
  ULONG CategoryId;
  ULONG AuditId;
  ULONG ParameterCount;
  ULONG Length;
  USHORT FlatSubCategoryId;
  USHORT Type;
  ULONG Flags;
  SE_ADT_PARAMETER_ARRAY_ENTRY Parameters[ SE_MAX_AUDIT_PARAMETERS ];
} SE_ADT_PARAMETER_ARRAY, *PSE_ADT_PARAMETER_ARRAY;

#endif /* !_NTLSA_AUDIT_ */
#endif /* !_NTLSA_IFS_ */

/******************************************************************************
 *                            Power Management Support Types                  *
 ******************************************************************************/

#ifndef _PO_DDK_
#define _PO_DDK_

#define PO_CB_SYSTEM_POWER_POLICY                0
#define PO_CB_AC_STATUS                          1
#define PO_CB_BUTTON_COLLISION                   2
#define PO_CB_SYSTEM_STATE_LOCK                  3
#define PO_CB_LID_SWITCH_STATE                   4
#define PO_CB_PROCESSOR_POWER_POLICY             5

/* Power States/Levels */
typedef enum _SYSTEM_POWER_STATE {
  PowerSystemUnspecified = 0,
  PowerSystemWorking,
  PowerSystemSleeping1,
  PowerSystemSleeping2,
  PowerSystemSleeping3,
  PowerSystemHibernate,
  PowerSystemShutdown,
  PowerSystemMaximum
} SYSTEM_POWER_STATE, *PSYSTEM_POWER_STATE;

#define POWER_SYSTEM_MAXIMUM PowerSystemMaximum

typedef enum _POWER_INFORMATION_LEVEL {
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
  PowerInformationLevelUnused1,
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
  PowerInformationLevelMaximum
} POWER_INFORMATION_LEVEL;

typedef enum {
  PowerActionNone = 0,
  PowerActionReserved,
  PowerActionSleep,
  PowerActionHibernate,
  PowerActionShutdown,
  PowerActionShutdownReset,
  PowerActionShutdownOff,
  PowerActionWarmEject
} POWER_ACTION, *PPOWER_ACTION;

typedef enum _DEVICE_POWER_STATE {
  PowerDeviceUnspecified = 0,
  PowerDeviceD0,
  PowerDeviceD1,
  PowerDeviceD2,
  PowerDeviceD3,
  PowerDeviceMaximum
} DEVICE_POWER_STATE, *PDEVICE_POWER_STATE;

typedef enum _MONITOR_DISPLAY_STATE {
  PowerMonitorOff = 0,
  PowerMonitorOn,
  PowerMonitorDim
} MONITOR_DISPLAY_STATE, *PMONITOR_DISPLAY_STATE;

typedef union _POWER_STATE {
  SYSTEM_POWER_STATE SystemState;
  DEVICE_POWER_STATE DeviceState;
} POWER_STATE, *PPOWER_STATE;

typedef enum _POWER_STATE_TYPE {
  SystemPowerState = 0,
  DevicePowerState
} POWER_STATE_TYPE, *PPOWER_STATE_TYPE;

#if (NTDDI_VERSION >= NTDDI_VISTA)
typedef struct _SYSTEM_POWER_STATE_CONTEXT {
  _ANONYMOUS_UNION union {
    _ANONYMOUS_STRUCT struct {
      ULONG Reserved1:8;
      ULONG TargetSystemState:4;
      ULONG EffectiveSystemState:4;
      ULONG CurrentSystemState:4;
      ULONG IgnoreHibernationPath:1;
      ULONG PseudoTransition:1;
      ULONG Reserved2:10;
    } DUMMYSTRUCTNAME;
    ULONG ContextAsUlong;
  } DUMMYUNIONNAME;
} SYSTEM_POWER_STATE_CONTEXT, *PSYSTEM_POWER_STATE_CONTEXT;
#endif

#if (NTDDI_VERSION >= NTDDI_WIN7)
typedef struct _COUNTED_REASON_CONTEXT {
  ULONG Version;
  ULONG Flags;
  _ANONYMOUS_UNION union {
    _ANONYMOUS_STRUCT struct {
      UNICODE_STRING ResourceFileName;
      USHORT ResourceReasonId;
      ULONG StringCount;
      PUNICODE_STRING ReasonStrings;
    } DUMMYSTRUCTNAME;
    UNICODE_STRING SimpleString;
  } DUMMYUNIONNAME;
} COUNTED_REASON_CONTEXT, *PCOUNTED_REASON_CONTEXT;
#endif

#define IOCTL_QUERY_DEVICE_POWER_STATE  \
        CTL_CODE(FILE_DEVICE_BATTERY, 0x0, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_SET_DEVICE_WAKE           \
        CTL_CODE(FILE_DEVICE_BATTERY, 0x1, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define IOCTL_CANCEL_DEVICE_WAKE        \
        CTL_CODE(FILE_DEVICE_BATTERY, 0x2, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define ES_SYSTEM_REQUIRED                       0x00000001
#define ES_DISPLAY_REQUIRED                      0x00000002
#define ES_USER_PRESENT                          0x00000004
#define ES_CONTINUOUS                            0x80000000

typedef ULONG EXECUTION_STATE, *PEXECUTION_STATE;

typedef enum {
  LT_DONT_CARE,
  LT_LOWEST_LATENCY
} LATENCY_TIME;

#if (_WIN32_WINNT >= _WIN32_WINNT_WIN7)
#define DIAGNOSTIC_REASON_VERSION                0
#define DIAGNOSTIC_REASON_SIMPLE_STRING          0x00000001
#define DIAGNOSTIC_REASON_DETAILED_STRING        0x00000002
#define DIAGNOSTIC_REASON_NOT_SPECIFIED          0x80000000
#define DIAGNOSTIC_REASON_INVALID_FLAGS          (~0x80000003)
#endif

#define POWER_REQUEST_CONTEXT_VERSION            0
#define POWER_REQUEST_CONTEXT_SIMPLE_STRING      0x00000001
#define POWER_REQUEST_CONTEXT_DETAILED_STRING    0x00000002

#define PowerRequestMaximum                      3

typedef enum _POWER_REQUEST_TYPE {
  PowerRequestDisplayRequired,
  PowerRequestSystemRequired,
  PowerRequestAwayModeRequired
} POWER_REQUEST_TYPE, *PPOWER_REQUEST_TYPE;

#if (NTDDI_VERSION >= NTDDI_WINXP)

#define PDCAP_D0_SUPPORTED                       0x00000001
#define PDCAP_D1_SUPPORTED                       0x00000002
#define PDCAP_D2_SUPPORTED                       0x00000004
#define PDCAP_D3_SUPPORTED                       0x00000008
#define PDCAP_WAKE_FROM_D0_SUPPORTED             0x00000010
#define PDCAP_WAKE_FROM_D1_SUPPORTED             0x00000020
#define PDCAP_WAKE_FROM_D2_SUPPORTED             0x00000040
#define PDCAP_WAKE_FROM_D3_SUPPORTED             0x00000080
#define PDCAP_WARM_EJECT_SUPPORTED               0x00000100

typedef struct CM_Power_Data_s {
  ULONG PD_Size;
  DEVICE_POWER_STATE PD_MostRecentPowerState;
  ULONG PD_Capabilities;
  ULONG PD_D1Latency;
  ULONG PD_D2Latency;
  ULONG PD_D3Latency;
  DEVICE_POWER_STATE PD_PowerStateMapping[PowerSystemMaximum];
  SYSTEM_POWER_STATE PD_DeepestSystemWake;
} CM_POWER_DATA, *PCM_POWER_DATA;

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

typedef enum _SYSTEM_POWER_CONDITION {
  PoAc,
  PoDc,
  PoHot,
  PoConditionMaximum
} SYSTEM_POWER_CONDITION;

typedef struct _SET_POWER_SETTING_VALUE {
  ULONG Version;
  GUID Guid;
  SYSTEM_POWER_CONDITION PowerCondition;
  ULONG DataLength;
  UCHAR Data[ANYSIZE_ARRAY];
} SET_POWER_SETTING_VALUE, *PSET_POWER_SETTING_VALUE;

#define POWER_SETTING_VALUE_VERSION              (0x1)

typedef struct _NOTIFY_USER_POWER_SETTING {
  GUID Guid;
} NOTIFY_USER_POWER_SETTING, *PNOTIFY_USER_POWER_SETTING;

typedef struct _APPLICATIONLAUNCH_SETTING_VALUE {
  LARGE_INTEGER ActivationTime;
  ULONG Flags;
  ULONG ButtonInstanceID;
} APPLICATIONLAUNCH_SETTING_VALUE, *PAPPLICATIONLAUNCH_SETTING_VALUE;

typedef enum _POWER_PLATFORM_ROLE {
  PlatformRoleUnspecified = 0,
  PlatformRoleDesktop,
  PlatformRoleMobile,
  PlatformRoleWorkstation,
  PlatformRoleEnterpriseServer,
  PlatformRoleSOHOServer,
  PlatformRoleAppliancePC,
  PlatformRolePerformanceServer,
  PlatformRoleMaximum
} POWER_PLATFORM_ROLE;

#if (NTDDI_VERSION >= NTDDI_WINXP) || !defined(_BATCLASS_)
typedef struct {
  ULONG Granularity;
  ULONG Capacity;
} BATTERY_REPORTING_SCALE, *PBATTERY_REPORTING_SCALE;
#endif /* (NTDDI_VERSION >= NTDDI_WINXP) || !defined(_BATCLASS_) */

#endif /* !_PO_DDK_ */

#define CORE_PARKING_POLICY_CHANGE_IDEAL         0
#define CORE_PARKING_POLICY_CHANGE_SINGLE        1
#define CORE_PARKING_POLICY_CHANGE_ROCKET        2
#define CORE_PARKING_POLICY_CHANGE_MAX           CORE_PARKING_POLICY_CHANGE_ROCKET

DEFINE_GUID(GUID_MAX_POWER_SAVINGS, 0xA1841308, 0x3541, 0x4FAB, 0xBC, 0x81, 0xF7, 0x15, 0x56, 0xF2, 0x0B, 0x4A);
DEFINE_GUID(GUID_MIN_POWER_SAVINGS, 0x8C5E7FDA, 0xE8BF, 0x4A96, 0x9A, 0x85, 0xA6, 0xE2, 0x3A, 0x8C, 0x63, 0x5C);
DEFINE_GUID(GUID_TYPICAL_POWER_SAVINGS, 0x381B4222, 0xF694, 0x41F0, 0x96, 0x85, 0xFF, 0x5B, 0xB2, 0x60, 0xDF, 0x2E);
DEFINE_GUID(NO_SUBGROUP_GUID, 0xFEA3413E, 0x7E05, 0x4911, 0x9A, 0x71, 0x70, 0x03, 0x31, 0xF1, 0xC2, 0x94);
DEFINE_GUID(ALL_POWERSCHEMES_GUID, 0x68A1E95E, 0x13EA, 0x41E1, 0x80, 0x11, 0x0C, 0x49, 0x6C, 0xA4, 0x90, 0xB0);
DEFINE_GUID(GUID_POWERSCHEME_PERSONALITY, 0x245D8541, 0x3943, 0x4422, 0xB0, 0x25, 0x13, 0xA7, 0x84, 0xF6, 0x79, 0xB7);
DEFINE_GUID(GUID_ACTIVE_POWERSCHEME, 0x31F9F286, 0x5084, 0x42FE, 0xB7, 0x20, 0x2B, 0x02, 0x64, 0x99, 0x37, 0x63);
DEFINE_GUID(GUID_VIDEO_SUBGROUP, 0x7516B95F, 0xF776, 0x4464, 0x8C, 0x53, 0x06, 0x16, 0x7F, 0x40, 0xCC, 0x99);
DEFINE_GUID(GUID_VIDEO_POWERDOWN_TIMEOUT, 0x3C0BC021, 0xC8A8, 0x4E07, 0xA9, 0x73, 0x6B, 0x14, 0xCB, 0xCB, 0x2B, 0x7E);
DEFINE_GUID(GUID_VIDEO_ANNOYANCE_TIMEOUT, 0x82DBCF2D, 0xCD67, 0x40C5, 0xBF, 0xDC, 0x9F, 0x1A, 0x5C, 0xCD, 0x46, 0x63);
DEFINE_GUID(GUID_VIDEO_ADAPTIVE_PERCENT_INCREASE, 0xEED904DF, 0xB142, 0x4183, 0xB1, 0x0B, 0x5A, 0x11, 0x97, 0xA3, 0x78, 0x64);
DEFINE_GUID(GUID_VIDEO_DIM_TIMEOUT, 0x17aaa29b, 0x8b43, 0x4b94, 0xaa, 0xfe, 0x35, 0xf6, 0x4d, 0xaa, 0xf1, 0xee);
DEFINE_GUID(GUID_VIDEO_ADAPTIVE_POWERDOWN, 0x90959D22, 0xD6A1, 0x49B9, 0xAF, 0x93, 0xBC, 0xE8, 0x85, 0xAD, 0x33, 0x5B);
DEFINE_GUID(GUID_MONITOR_POWER_ON, 0x02731015, 0x4510, 0x4526, 0x99, 0xE6, 0xE5, 0xA1, 0x7E, 0xBD, 0x1A, 0xEA);
DEFINE_GUID(GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS, 0xaded5e82L, 0xb909, 0x4619, 0x99, 0x49, 0xf5, 0xd7, 0x1d, 0xac, 0x0b, 0xcb);
DEFINE_GUID(GUID_DEVICE_POWER_POLICY_VIDEO_DIM_BRIGHTNESS, 0xf1fbfde2, 0xa960, 0x4165, 0x9f, 0x88, 0x50, 0x66, 0x79, 0x11, 0xce, 0x96);
DEFINE_GUID(GUID_VIDEO_CURRENT_MONITOR_BRIGHTNESS, 0x8ffee2c6, 0x2d01, 0x46be, 0xad, 0xb9, 0x39, 0x8a, 0xdd, 0xc5, 0xb4, 0xff);
DEFINE_GUID(GUID_VIDEO_ADAPTIVE_DISPLAY_BRIGHTNESS, 0xFBD9AA66, 0x9553, 0x4097, 0xBA, 0x44, 0xED, 0x6E, 0x9D, 0x65, 0xEA, 0xB8);
DEFINE_GUID(GUID_SESSION_DISPLAY_STATE, 0x73A5E93A, 0x5BB1, 0x4F93, 0x89, 0x5B, 0xDB, 0xD0, 0xDA, 0x85, 0x59, 0x67);
DEFINE_GUID(GUID_CONSOLE_DISPLAY_STATE, 0x6fe69556, 0x704a, 0x47a0, 0x8f, 0x24, 0xc2, 0x8d, 0x93, 0x6f, 0xda, 0x47);
DEFINE_GUID(GUID_ALLOW_DISPLAY_REQUIRED, 0xA9CEB8DA, 0xCD46, 0x44FB, 0xA9, 0x8B, 0x02, 0xAF, 0x69, 0xDE, 0x46, 0x23);
DEFINE_GUID(GUID_DISK_SUBGROUP, 0x0012EE47, 0x9041, 0x4B5D, 0x9B, 0x77, 0x53, 0x5F, 0xBA, 0x8B, 0x14, 0x42);
DEFINE_GUID(GUID_DISK_POWERDOWN_TIMEOUT, 0x6738E2C4, 0xE8A5, 0x4A42, 0xB1, 0x6A, 0xE0, 0x40, 0xE7, 0x69, 0x75, 0x6E);
DEFINE_GUID(GUID_DISK_BURST_IGNORE_THRESHOLD, 0x80e3c60e, 0xbb94, 0x4ad8, 0xbb, 0xe0, 0x0d, 0x31, 0x95, 0xef, 0xc6, 0x63);
DEFINE_GUID(GUID_DISK_ADAPTIVE_POWERDOWN, 0x396A32E1, 0x499A, 0x40B2, 0x91, 0x24, 0xA9, 0x6A, 0xFE, 0x70, 0x76, 0x67);
DEFINE_GUID(GUID_SLEEP_SUBGROUP, 0x238C9FA8, 0x0AAD, 0x41ED, 0x83, 0xF4, 0x97, 0xBE, 0x24, 0x2C, 0x8F, 0x20);
DEFINE_GUID(GUID_SLEEP_IDLE_THRESHOLD, 0x81cd32e0, 0x7833, 0x44f3, 0x87, 0x37, 0x70, 0x81, 0xf3, 0x8d, 0x1f, 0x70);
DEFINE_GUID(GUID_STANDBY_TIMEOUT, 0x29F6C1DB, 0x86DA, 0x48C5, 0x9F, 0xDB, 0xF2, 0xB6, 0x7B, 0x1F, 0x44, 0xDA);
DEFINE_GUID(GUID_UNATTEND_SLEEP_TIMEOUT, 0x7bc4a2f9, 0xd8fc, 0x4469, 0xb0, 0x7b, 0x33, 0xeb, 0x78, 0x5a, 0xac, 0xa0);
DEFINE_GUID(GUID_HIBERNATE_TIMEOUT, 0x9D7815A6, 0x7EE4, 0x497E, 0x88, 0x88, 0x51, 0x5A, 0x05, 0xF0, 0x23, 0x64);
DEFINE_GUID(GUID_HIBERNATE_FASTS4_POLICY, 0x94AC6D29, 0x73CE, 0x41A6, 0x80, 0x9F, 0x63, 0x63, 0xBA, 0x21, 0xB4, 0x7E);
DEFINE_GUID(GUID_CRITICAL_POWER_TRANSITION,  0xB7A27025, 0xE569, 0x46c2, 0xA5, 0x04, 0x2B, 0x96, 0xCA, 0xD2, 0x25, 0xA1);
DEFINE_GUID(GUID_SYSTEM_AWAYMODE, 0x98A7F580, 0x01F7, 0x48AA, 0x9C, 0x0F, 0x44, 0x35, 0x2C, 0x29, 0xE5, 0xC0);
DEFINE_GUID(GUID_ALLOW_AWAYMODE, 0x25dfa149, 0x5dd1, 0x4736, 0xb5, 0xab, 0xe8, 0xa3, 0x7b, 0x5b, 0x81, 0x87);
DEFINE_GUID(GUID_ALLOW_STANDBY_STATES, 0xabfc2519, 0x3608, 0x4c2a, 0x94, 0xea, 0x17, 0x1b, 0x0e, 0xd5, 0x46, 0xab);
DEFINE_GUID(GUID_ALLOW_RTC_WAKE, 0xBD3B718A, 0x0680, 0x4D9D, 0x8A, 0xB2, 0xE1, 0xD2, 0xB4, 0xAC, 0x80, 0x6D);
DEFINE_GUID(GUID_ALLOW_SYSTEM_REQUIRED, 0xA4B195F5, 0x8225, 0x47D8, 0x80, 0x12, 0x9D, 0x41, 0x36, 0x97, 0x86, 0xE2);
DEFINE_GUID(GUID_SYSTEM_BUTTON_SUBGROUP, 0x4F971E89, 0xEEBD, 0x4455, 0xA8, 0xDE, 0x9E, 0x59, 0x04, 0x0E, 0x73, 0x47);
DEFINE_GUID(GUID_POWERBUTTON_ACTION, 0x7648EFA3, 0xDD9C, 0x4E3E, 0xB5, 0x66, 0x50, 0xF9, 0x29, 0x38, 0x62, 0x80);
DEFINE_GUID(GUID_POWERBUTTON_ACTION_FLAGS, 0x857E7FAC, 0x034B, 0x4704, 0xAB, 0xB1, 0xBC, 0xA5, 0x4A, 0xA3, 0x14, 0x78);
DEFINE_GUID(GUID_SLEEPBUTTON_ACTION, 0x96996BC0, 0xAD50, 0x47EC, 0x92, 0x3B, 0x6F, 0x41, 0x87, 0x4D, 0xD9, 0xEB);
DEFINE_GUID(GUID_SLEEPBUTTON_ACTION_FLAGS, 0x2A160AB1, 0xB69D, 0x4743, 0xB7, 0x18, 0xBF, 0x14, 0x41, 0xD5, 0xE4, 0x93);
DEFINE_GUID(GUID_USERINTERFACEBUTTON_ACTION, 0xA7066653, 0x8D6C, 0x40A8, 0x91, 0x0E, 0xA1, 0xF5, 0x4B, 0x84, 0xC7, 0xE5);
DEFINE_GUID(GUID_LIDCLOSE_ACTION, 0x5CA83367, 0x6E45, 0x459F, 0xA2, 0x7B, 0x47, 0x6B, 0x1D, 0x01, 0xC9, 0x36);
DEFINE_GUID(GUID_LIDCLOSE_ACTION_FLAGS, 0x97E969AC, 0x0D6C, 0x4D08, 0x92, 0x7C, 0xD7, 0xBD, 0x7A, 0xD7, 0x85, 0x7B);
DEFINE_GUID(GUID_LIDOPEN_POWERSTATE, 0x99FF10E7, 0x23B1, 0x4C07, 0xA9, 0xD1, 0x5C, 0x32, 0x06, 0xD7, 0x41, 0xB4);
DEFINE_GUID(GUID_BATTERY_SUBGROUP, 0xE73A048D, 0xBF27, 0x4F12, 0x97, 0x31, 0x8B, 0x20, 0x76, 0xE8, 0x89, 0x1F);
DEFINE_GUID(GUID_BATTERY_DISCHARGE_ACTION_0, 0x637EA02F, 0xBBCB, 0x4015, 0x8E, 0x2C, 0xA1, 0xC7, 0xB9, 0xC0, 0xB5, 0x46);
DEFINE_GUID(GUID_BATTERY_DISCHARGE_LEVEL_0, 0x9A66D8D7, 0x4FF7, 0x4EF9, 0xB5, 0xA2, 0x5A, 0x32, 0x6C, 0xA2, 0xA4, 0x69);
DEFINE_GUID(GUID_BATTERY_DISCHARGE_FLAGS_0, 0x5dbb7c9f, 0x38e9, 0x40d2, 0x97, 0x49, 0x4f, 0x8a, 0x0e, 0x9f, 0x64, 0x0f);
DEFINE_GUID(GUID_BATTERY_DISCHARGE_ACTION_1, 0xD8742DCB, 0x3E6A, 0x4B3C, 0xB3, 0xFE, 0x37, 0x46, 0x23, 0xCD, 0xCF, 0x06);
DEFINE_GUID(GUID_BATTERY_DISCHARGE_LEVEL_1, 0x8183BA9A, 0xE910, 0x48DA, 0x87, 0x69, 0x14, 0xAE, 0x6D, 0xC1, 0x17, 0x0A);
DEFINE_GUID(GUID_BATTERY_DISCHARGE_FLAGS_1, 0xbcded951, 0x187b, 0x4d05, 0xbc, 0xcc, 0xf7, 0xe5, 0x19, 0x60, 0xc2, 0x58);
DEFINE_GUID(GUID_BATTERY_DISCHARGE_ACTION_2, 0x421CBA38, 0x1A8E, 0x4881, 0xAC, 0x89, 0xE3, 0x3A, 0x8B, 0x04, 0xEC, 0xE4);
DEFINE_GUID(GUID_BATTERY_DISCHARGE_LEVEL_2, 0x07A07CA2, 0xADAF, 0x40D7, 0xB0, 0x77, 0x53, 0x3A, 0xAD, 0xED, 0x1B, 0xFA);
DEFINE_GUID(GUID_BATTERY_DISCHARGE_FLAGS_2, 0x7fd2f0c4, 0xfeb7, 0x4da3, 0x81, 0x17, 0xe3, 0xfb, 0xed, 0xc4, 0x65, 0x82);
DEFINE_GUID(GUID_BATTERY_DISCHARGE_ACTION_3, 0x80472613, 0x9780, 0x455E, 0xB3, 0x08, 0x72, 0xD3, 0x00, 0x3C, 0xF2, 0xF8);
DEFINE_GUID(GUID_BATTERY_DISCHARGE_LEVEL_3, 0x58AFD5A6, 0xC2DD, 0x47D2, 0x9F, 0xBF, 0xEF, 0x70, 0xCC, 0x5C, 0x59, 0x65);
DEFINE_GUID(GUID_BATTERY_DISCHARGE_FLAGS_3, 0x73613ccf, 0xdbfa, 0x4279, 0x83, 0x56, 0x49, 0x35, 0xf6, 0xbf, 0x62, 0xf3);
DEFINE_GUID(GUID_PROCESSOR_SETTINGS_SUBGROUP, 0x54533251, 0x82BE, 0x4824, 0x96, 0xC1, 0x47, 0xB6, 0x0B, 0x74, 0x0D, 0x00);
DEFINE_GUID(GUID_PROCESSOR_THROTTLE_POLICY, 0x57027304, 0x4AF6, 0x4104, 0x92, 0x60, 0xE3, 0xD9, 0x52, 0x48, 0xFC, 0x36);
DEFINE_GUID(GUID_PROCESSOR_THROTTLE_MAXIMUM, 0xBC5038F7, 0x23E0, 0x4960, 0x96, 0xDA, 0x33, 0xAB, 0xAF, 0x59, 0x35, 0xEC);
DEFINE_GUID(GUID_PROCESSOR_THROTTLE_MINIMUM, 0x893DEE8E, 0x2BEF, 0x41E0, 0x89, 0xC6, 0xB5, 0x5D, 0x09, 0x29, 0x96, 0x4C);
DEFINE_GUID(GUID_PROCESSOR_ALLOW_THROTTLING, 0x3b04d4fd, 0x1cc7, 0x4f23, 0xab, 0x1c, 0xd1, 0x33, 0x78, 0x19, 0xc4, 0xbb);
DEFINE_GUID(GUID_PROCESSOR_IDLESTATE_POLICY, 0x68f262a7, 0xf621, 0x4069, 0xb9, 0xa5, 0x48, 0x74, 0x16, 0x9b, 0xe2, 0x3c);
DEFINE_GUID(GUID_PROCESSOR_PERFSTATE_POLICY, 0xBBDC3814, 0x18E9, 0x4463, 0x8A, 0x55, 0xD1, 0x97, 0x32, 0x7C, 0x45, 0xC0);
DEFINE_GUID(GUID_PROCESSOR_PERF_INCREASE_THRESHOLD, 0x06cadf0e, 0x64ed, 0x448a, 0x89, 0x27, 0xce, 0x7b, 0xf9, 0x0e, 0xb3, 0x5d);
DEFINE_GUID(GUID_PROCESSOR_PERF_DECREASE_THRESHOLD, 0x12a0ab44, 0xfe28, 0x4fa9, 0xb3, 0xbd, 0x4b, 0x64, 0xf4, 0x49, 0x60, 0xa6);
DEFINE_GUID(GUID_PROCESSOR_PERF_INCREASE_POLICY, 0x465e1f50, 0xb610, 0x473a, 0xab, 0x58, 0x0, 0xd1, 0x7, 0x7d, 0xc4, 0x18);
DEFINE_GUID(GUID_PROCESSOR_PERF_DECREASE_POLICY, 0x40fbefc7, 0x2e9d, 0x4d25, 0xa1, 0x85, 0xc, 0xfd, 0x85, 0x74, 0xba, 0xc6);
DEFINE_GUID(GUID_PROCESSOR_PERF_INCREASE_TIME, 0x984cf492, 0x3bed, 0x4488, 0xa8, 0xf9, 0x42, 0x86, 0xc9, 0x7b, 0xf5, 0xaa);
DEFINE_GUID(GUID_PROCESSOR_PERF_DECREASE_TIME, 0xd8edeb9b, 0x95cf, 0x4f95, 0xa7, 0x3c, 0xb0, 0x61, 0x97, 0x36, 0x93, 0xc8);
DEFINE_GUID(GUID_PROCESSOR_PERF_TIME_CHECK, 0x4d2b0152, 0x7d5c, 0x498b, 0x88, 0xe2, 0x34, 0x34, 0x53, 0x92, 0xa2, 0xc5);
DEFINE_GUID(GUID_PROCESSOR_PERF_BOOST_POLICY, 0x45bcc044, 0xd885, 0x43e2, 0x86, 0x5, 0xee, 0xe, 0xc6, 0xe9, 0x6b, 0x59);
DEFINE_GUID(GUID_PROCESSOR_IDLE_ALLOW_SCALING, 0x6c2993b0, 0x8f48, 0x481f, 0xbc, 0xc6, 0x0, 0xdd, 0x27, 0x42, 0xaa, 0x6);
DEFINE_GUID(GUID_PROCESSOR_IDLE_DISABLE, 0x5d76a2ca, 0xe8c0, 0x402f, 0xa1, 0x33, 0x21, 0x58, 0x49, 0x2d, 0x58, 0xad);
DEFINE_GUID(GUID_PROCESSOR_IDLE_TIME_CHECK, 0xc4581c31, 0x89ab, 0x4597, 0x8e, 0x2b, 0x9c, 0x9c, 0xab, 0x44, 0xe, 0x6b);
DEFINE_GUID(GUID_PROCESSOR_IDLE_DEMOTE_THRESHOLD, 0x4b92d758, 0x5a24, 0x4851, 0xa4, 0x70, 0x81, 0x5d, 0x78, 0xae, 0xe1, 0x19);
DEFINE_GUID(GUID_PROCESSOR_IDLE_PROMOTE_THRESHOLD, 0x7b224883, 0xb3cc, 0x4d79, 0x81, 0x9f, 0x83, 0x74, 0x15, 0x2c, 0xbe, 0x7c);
DEFINE_GUID(GUID_PROCESSOR_CORE_PARKING_INCREASE_THRESHOLD, 0xdf142941, 0x20f3, 0x4edf, 0x9a, 0x4a, 0x9c, 0x83, 0xd3, 0xd7, 0x17, 0xd1);
DEFINE_GUID(GUID_PROCESSOR_CORE_PARKING_DECREASE_THRESHOLD, 0x68dd2f27, 0xa4ce, 0x4e11, 0x84, 0x87, 0x37, 0x94, 0xe4, 0x13, 0x5d, 0xfa);
DEFINE_GUID(GUID_PROCESSOR_CORE_PARKING_INCREASE_POLICY, 0xc7be0679, 0x2817, 0x4d69, 0x9d, 0x02, 0x51, 0x9a, 0x53, 0x7e, 0xd0, 0xc6);
DEFINE_GUID(GUID_PROCESSOR_CORE_PARKING_DECREASE_POLICY, 0x71021b41, 0xc749, 0x4d21, 0xbe, 0x74, 0xa0, 0x0f, 0x33, 0x5d, 0x58, 0x2b);
DEFINE_GUID(GUID_PROCESSOR_CORE_PARKING_MAX_CORES, 0xea062031, 0x0e34, 0x4ff1, 0x9b, 0x6d, 0xeb, 0x10, 0x59, 0x33, 0x40, 0x28);
DEFINE_GUID(GUID_PROCESSOR_CORE_PARKING_MIN_CORES, 0x0cc5b647, 0xc1df, 0x4637, 0x89, 0x1a, 0xde, 0xc3, 0x5c, 0x31, 0x85, 0x83);
DEFINE_GUID(GUID_PROCESSOR_CORE_PARKING_INCREASE_TIME, 0x2ddd5a84, 0x5a71, 0x437e, 0x91, 0x2a, 0xdb, 0x0b, 0x8c, 0x78, 0x87, 0x32);
DEFINE_GUID(GUID_PROCESSOR_CORE_PARKING_DECREASE_TIME, 0xdfd10d17, 0xd5eb, 0x45dd, 0x87, 0x7a, 0x9a, 0x34, 0xdd, 0xd1, 0x5c, 0x82);
DEFINE_GUID(GUID_PROCESSOR_CORE_PARKING_AFFINITY_HISTORY_DECREASE_FACTOR, 0x8f7b45e3, 0xc393, 0x480a, 0x87, 0x8c, 0xf6, 0x7a, 0xc3, 0xd0, 0x70, 0x82);
DEFINE_GUID(GUID_PROCESSOR_CORE_PARKING_AFFINITY_HISTORY_THRESHOLD, 0x5b33697b, 0xe89d, 0x4d38, 0xaa, 0x46, 0x9e, 0x7d, 0xfb, 0x7c, 0xd2, 0xf9);
DEFINE_GUID(GUID_PROCESSOR_CORE_PARKING_AFFINITY_WEIGHTING, 0xe70867f1, 0xfa2f, 0x4f4e, 0xae, 0xa1, 0x4d, 0x8a, 0x0b, 0xa2, 0x3b, 0x20);
DEFINE_GUID(GUID_PROCESSOR_CORE_PARKING_OVER_UTILIZATION_HISTORY_DECREASE_FACTOR, 0x1299023c, 0xbc28, 0x4f0a, 0x81, 0xec, 0xd3, 0x29, 0x5a, 0x8d, 0x81, 0x5d);
DEFINE_GUID(GUID_PROCESSOR_CORE_PARKING_OVER_UTILIZATION_HISTORY_THRESHOLD, 0x9ac18e92, 0xaa3c, 0x4e27, 0xb3, 0x07, 0x01, 0xae, 0x37, 0x30, 0x71, 0x29);
DEFINE_GUID(GUID_PROCESSOR_CORE_PARKING_OVER_UTILIZATION_WEIGHTING, 0x8809c2d8, 0xb155, 0x42d4, 0xbc, 0xda, 0x0d, 0x34, 0x56, 0x51, 0xb1, 0xdb);
DEFINE_GUID(GUID_PROCESSOR_CORE_PARKING_OVER_UTILIZATION_THRESHOLD, 0x943c8cb6, 0x6f93, 0x4227, 0xad, 0x87, 0xe9, 0xa3, 0xfe, 0xec, 0x08, 0xd1);
DEFINE_GUID(GUID_PROCESSOR_PARKING_CORE_OVERRIDE, 0xa55612aa, 0xf624, 0x42c6, 0xa4, 0x43, 0x73, 0x97, 0xd0, 0x64, 0xc0, 0x4f);
DEFINE_GUID(GUID_PROCESSOR_PARKING_PERF_STATE, 0x447235c7, 0x6a8d, 0x4cc0, 0x8e, 0x24, 0x9e, 0xaf, 0x70, 0xb9, 0x6e, 0x2b);
DEFINE_GUID(GUID_PROCESSOR_PERF_HISTORY, 0x7d24baa7, 0x0b84, 0x480f, 0x84, 0x0c, 0x1b, 0x07, 0x43, 0xc0, 0x0f, 0x5f);
DEFINE_GUID(GUID_SYSTEM_COOLING_POLICY, 0x94D3A615, 0xA899, 0x4AC5, 0xAE, 0x2B, 0xE4, 0xD8, 0xF6, 0x34, 0x36, 0x7F);
DEFINE_GUID(GUID_LOCK_CONSOLE_ON_WAKE, 0x0E796BDB, 0x100D, 0x47D6, 0xA2, 0xD5, 0xF7, 0xD2, 0xDA, 0xA5, 0x1F, 0x51);
DEFINE_GUID(GUID_DEVICE_IDLE_POLICY, 0x4faab71a, 0x92e5, 0x4726, 0xb5, 0x31, 0x22, 0x45, 0x59, 0x67, 0x2d, 0x19);
DEFINE_GUID(GUID_ACDC_POWER_SOURCE, 0x5D3E9A59, 0xE9D5, 0x4B00, 0xA6, 0xBD, 0xFF, 0x34, 0xFF, 0x51, 0x65, 0x48);
DEFINE_GUID(GUID_LIDSWITCH_STATE_CHANGE,  0xBA3E0F4D, 0xB817, 0x4094, 0xA2, 0xD1, 0xD5, 0x63, 0x79, 0xE6, 0xA0, 0xF3);
DEFINE_GUID(GUID_BATTERY_PERCENTAGE_REMAINING, 0xA7AD8041, 0xB45A, 0x4CAE, 0x87, 0xA3, 0xEE, 0xCB, 0xB4, 0x68, 0xA9, 0xE1);
DEFINE_GUID(GUID_IDLE_BACKGROUND_TASK, 0x515C31D8, 0xF734, 0x163D, 0xA0, 0xFD, 0x11, 0xA0, 0x8C, 0x91, 0xE8, 0xF1);
DEFINE_GUID(GUID_BACKGROUND_TASK_NOTIFICATION, 0xCF23F240, 0x2A54, 0x48D8, 0xB1, 0x14, 0xDE, 0x15, 0x18, 0xFF, 0x05, 0x2E);
DEFINE_GUID(GUID_APPLAUNCH_BUTTON, 0x1A689231, 0x7399, 0x4E9A, 0x8F, 0x99, 0xB7, 0x1F, 0x99, 0x9D, 0xB3, 0xFA);
DEFINE_GUID(GUID_PCIEXPRESS_SETTINGS_SUBGROUP, 0x501a4d13, 0x42af,0x4429, 0x9f, 0xd1, 0xa8, 0x21, 0x8c, 0x26, 0x8e, 0x20);
DEFINE_GUID(GUID_PCIEXPRESS_ASPM_POLICY, 0xee12f906, 0xd277, 0x404b, 0xb6, 0xda, 0xe5, 0xfa, 0x1a, 0x57, 0x6d, 0xf5);
DEFINE_GUID(GUID_ENABLE_SWITCH_FORCED_SHUTDOWN, 0x833a6b62, 0xdfa4, 0x46d1, 0x82, 0xf8, 0xe0, 0x9e, 0x34, 0xd0, 0x29, 0xd6);

#define PERFSTATE_POLICY_CHANGE_IDEAL            0
#define PERFSTATE_POLICY_CHANGE_SINGLE           1
#define PERFSTATE_POLICY_CHANGE_ROCKET           2
#define PERFSTATE_POLICY_CHANGE_MAX              PERFSTATE_POLICY_CHANGE_ROCKET

#define PROCESSOR_PERF_BOOST_POLICY_DISABLED     0
#define PROCESSOR_PERF_BOOST_POLICY_MAX          100

#define POWER_DEVICE_IDLE_POLICY_PERFORMANCE     0
#define POWER_DEVICE_IDLE_POLICY_CONSERVATIVE    1

typedef VOID
(NTAPI REQUEST_POWER_COMPLETE)(
  IN struct _DEVICE_OBJECT *DeviceObject,
  IN UCHAR MinorFunction,
  IN POWER_STATE PowerState,
  IN PVOID Context,
  IN struct _IO_STATUS_BLOCK *IoStatus);
typedef REQUEST_POWER_COMPLETE *PREQUEST_POWER_COMPLETE;

typedef
NTSTATUS
(NTAPI POWER_SETTING_CALLBACK)(
  IN LPCGUID SettingGuid,
  IN PVOID Value,
  IN ULONG ValueLength,
  IN OUT PVOID Context OPTIONAL);
typedef POWER_SETTING_CALLBACK *PPOWER_SETTING_CALLBACK;

/******************************************************************************
 *                            Configuration Manager Types                     *
 ******************************************************************************/

/* Resource list definitions */
typedef int CM_RESOURCE_TYPE;

#define CmResourceTypeNull              0
#define CmResourceTypePort              1
#define CmResourceTypeInterrupt         2
#define CmResourceTypeMemory            3
#define CmResourceTypeDma               4
#define CmResourceTypeDeviceSpecific    5
#define CmResourceTypeBusNumber         6
#define CmResourceTypeNonArbitrated     128
#define CmResourceTypeConfigData        128
#define CmResourceTypeDevicePrivate     129
#define CmResourceTypePcCardConfig      130
#define CmResourceTypeMfCardConfig      131

/* KEY_VALUE_Xxx.Type */
#define REG_NONE                           0
#define REG_SZ                             1
#define REG_EXPAND_SZ                      2
#define REG_BINARY                         3
#define REG_DWORD                          4
#define REG_DWORD_LITTLE_ENDIAN            4
#define REG_DWORD_BIG_ENDIAN               5
#define REG_LINK                           6
#define REG_MULTI_SZ                       7
#define REG_RESOURCE_LIST                  8
#define REG_FULL_RESOURCE_DESCRIPTOR       9
#define REG_RESOURCE_REQUIREMENTS_LIST     10
#define REG_QWORD                          11
#define REG_QWORD_LITTLE_ENDIAN            11

/* Registry Access Rights */
#define KEY_QUERY_VALUE         (0x0001)
#define KEY_SET_VALUE           (0x0002)
#define KEY_CREATE_SUB_KEY      (0x0004)
#define KEY_ENUMERATE_SUB_KEYS  (0x0008)
#define KEY_NOTIFY              (0x0010)
#define KEY_CREATE_LINK         (0x0020)
#define KEY_WOW64_32KEY         (0x0200)
#define KEY_WOW64_64KEY         (0x0100)
#define KEY_WOW64_RES           (0x0300)

#define KEY_READ                ((STANDARD_RIGHTS_READ       |\
                                  KEY_QUERY_VALUE            |\
                                  KEY_ENUMERATE_SUB_KEYS     |\
                                  KEY_NOTIFY)                 \
                                  &                           \
                                 (~SYNCHRONIZE))

#define KEY_WRITE               ((STANDARD_RIGHTS_WRITE      |\
                                  KEY_SET_VALUE              |\
                                  KEY_CREATE_SUB_KEY)         \
                                  &                           \
                                 (~SYNCHRONIZE))

#define KEY_EXECUTE             ((KEY_READ)                   \
                                  &                           \
                                 (~SYNCHRONIZE))

#define KEY_ALL_ACCESS          ((STANDARD_RIGHTS_ALL        |\
                                  KEY_QUERY_VALUE            |\
                                  KEY_SET_VALUE              |\
                                  KEY_CREATE_SUB_KEY         |\
                                  KEY_ENUMERATE_SUB_KEYS     |\
                                  KEY_NOTIFY                 |\
                                  KEY_CREATE_LINK)            \
                                  &                           \
                                 (~SYNCHRONIZE))

/* Registry Open/Create Options */
#define REG_OPTION_RESERVED         (0x00000000L)
#define REG_OPTION_NON_VOLATILE     (0x00000000L)
#define REG_OPTION_VOLATILE         (0x00000001L)
#define REG_OPTION_CREATE_LINK      (0x00000002L)
#define REG_OPTION_BACKUP_RESTORE   (0x00000004L)
#define REG_OPTION_OPEN_LINK        (0x00000008L)

#define REG_LEGAL_OPTION            \
                (REG_OPTION_RESERVED            |\
                 REG_OPTION_NON_VOLATILE        |\
                 REG_OPTION_VOLATILE            |\
                 REG_OPTION_CREATE_LINK         |\
                 REG_OPTION_BACKUP_RESTORE      |\
                 REG_OPTION_OPEN_LINK)

#define REG_OPEN_LEGAL_OPTION       \
                (REG_OPTION_RESERVED            |\
                 REG_OPTION_BACKUP_RESTORE      |\
                 REG_OPTION_OPEN_LINK)

#define REG_STANDARD_FORMAT            1
#define REG_LATEST_FORMAT              2
#define REG_NO_COMPRESSION             4

/* Key creation/open disposition */
#define REG_CREATED_NEW_KEY         (0x00000001L)
#define REG_OPENED_EXISTING_KEY     (0x00000002L)

/* Key restore & hive load flags */
#define REG_WHOLE_HIVE_VOLATILE         (0x00000001L)
#define REG_REFRESH_HIVE                (0x00000002L)
#define REG_NO_LAZY_FLUSH               (0x00000004L)
#define REG_FORCE_RESTORE               (0x00000008L)
#define REG_APP_HIVE                    (0x00000010L)
#define REG_PROCESS_PRIVATE             (0x00000020L)
#define REG_START_JOURNAL               (0x00000040L)
#define REG_HIVE_EXACT_FILE_GROWTH      (0x00000080L)
#define REG_HIVE_NO_RM                  (0x00000100L)
#define REG_HIVE_SINGLE_LOG             (0x00000200L)
#define REG_BOOT_HIVE                   (0x00000400L)

/* Unload Flags */
#define REG_FORCE_UNLOAD            1

/* Notify Filter Values */
#define REG_NOTIFY_CHANGE_NAME          (0x00000001L)
#define REG_NOTIFY_CHANGE_ATTRIBUTES    (0x00000002L)
#define REG_NOTIFY_CHANGE_LAST_SET      (0x00000004L)
#define REG_NOTIFY_CHANGE_SECURITY      (0x00000008L)

#define REG_LEGAL_CHANGE_FILTER                 \
                (REG_NOTIFY_CHANGE_NAME          |\
                 REG_NOTIFY_CHANGE_ATTRIBUTES    |\
                 REG_NOTIFY_CHANGE_LAST_SET      |\
                 REG_NOTIFY_CHANGE_SECURITY)

#include <pshpack4.h>
typedef struct _CM_PARTIAL_RESOURCE_DESCRIPTOR {
  UCHAR Type;
  UCHAR ShareDisposition;
  USHORT Flags;
  union {
    struct {
      PHYSICAL_ADDRESS Start;
      ULONG Length;
    } Generic;
    struct {
      PHYSICAL_ADDRESS Start;
      ULONG Length;
    } Port;
    struct {
#if defined(NT_PROCESSOR_GROUPS)
      USHORT Level;
      USHORT Group;
#else
      ULONG Level;
#endif
      ULONG Vector;
      KAFFINITY Affinity;
    } Interrupt;
#if (NTDDI_VERSION >= NTDDI_LONGHORN)
    struct {
      _ANONYMOUS_UNION union {
        struct {
#if defined(NT_PROCESSOR_GROUPS)
          USHORT Group;
#else
          USHORT Reserved;
#endif
          USHORT MessageCount;
          ULONG Vector;
          KAFFINITY Affinity;
        } Raw;
        struct {
#if defined(NT_PROCESSOR_GROUPS)
          USHORT Level;
          USHORT Group;
#else
          ULONG Level;
#endif
          ULONG Vector;
          KAFFINITY Affinity;
        } Translated;
      } DUMMYUNIONNAME;
    } MessageInterrupt;
#endif
    struct {
      PHYSICAL_ADDRESS Start;
      ULONG Length;
    } Memory;
    struct {
      ULONG Channel;
      ULONG Port;
      ULONG Reserved1;
    } Dma;
    struct {
      ULONG Data[3];
    } DevicePrivate;
    struct {
      ULONG Start;
      ULONG Length;
      ULONG Reserved;
    } BusNumber;
    struct {
      ULONG DataSize;
      ULONG Reserved1;
      ULONG Reserved2;
    } DeviceSpecificData;
#if (NTDDI_VERSION >= NTDDI_LONGHORN)
    struct {
      PHYSICAL_ADDRESS Start;
      ULONG Length40;
    } Memory40;
    struct {
      PHYSICAL_ADDRESS Start;
      ULONG Length48;
    } Memory48;
    struct {
      PHYSICAL_ADDRESS Start;
      ULONG Length64;
    } Memory64;
#endif
  } u;
} CM_PARTIAL_RESOURCE_DESCRIPTOR, *PCM_PARTIAL_RESOURCE_DESCRIPTOR;
#include <poppack.h>

/* CM_PARTIAL_RESOURCE_DESCRIPTOR.Type */
#define CmResourceTypeNull                0
#define CmResourceTypePort                1
#define CmResourceTypeInterrupt           2
#define CmResourceTypeMemory              3
#define CmResourceTypeDma                 4
#define CmResourceTypeDeviceSpecific      5
#define CmResourceTypeBusNumber           6
#define CmResourceTypeMemoryLarge         7
#define CmResourceTypeNonArbitrated       128
#define CmResourceTypeConfigData          128
#define CmResourceTypeDevicePrivate       129
#define CmResourceTypePcCardConfig        130
#define CmResourceTypeMfCardConfig        131

/* CM_PARTIAL_RESOURCE_DESCRIPTOR.ShareDisposition */
typedef enum _CM_SHARE_DISPOSITION {
  CmResourceShareUndetermined = 0,
  CmResourceShareDeviceExclusive,
  CmResourceShareDriverExclusive,
  CmResourceShareShared
} CM_SHARE_DISPOSITION;

/* CM_PARTIAL_RESOURCE_DESCRIPTOR.Flags if Type = CmResourceTypePort */
#define CM_RESOURCE_PORT_MEMORY           0x0000
#define CM_RESOURCE_PORT_IO               0x0001
#define CM_RESOURCE_PORT_10_BIT_DECODE    0x0004
#define CM_RESOURCE_PORT_12_BIT_DECODE    0x0008
#define CM_RESOURCE_PORT_16_BIT_DECODE    0x0010
#define CM_RESOURCE_PORT_POSITIVE_DECODE  0x0020
#define CM_RESOURCE_PORT_PASSIVE_DECODE   0x0040
#define CM_RESOURCE_PORT_WINDOW_DECODE    0x0080
#define CM_RESOURCE_PORT_BAR              0x0100

/* CM_PARTIAL_RESOURCE_DESCRIPTOR.Flags if Type = CmResourceTypeInterrupt */
#define CM_RESOURCE_INTERRUPT_LEVEL_SENSITIVE 0x0000
#define CM_RESOURCE_INTERRUPT_LATCHED         0x0001
#define CM_RESOURCE_INTERRUPT_MESSAGE         0x0002
#define CM_RESOURCE_INTERRUPT_POLICY_INCLUDED 0x0004

#define CM_RESOURCE_INTERRUPT_LEVEL_LATCHED_BITS 0x0001

#define CM_RESOURCE_INTERRUPT_MESSAGE_TOKEN   ((ULONG)-2)

/* CM_PARTIAL_RESOURCE_DESCRIPTOR.Flags if Type = CmResourceTypeMemory */
#define CM_RESOURCE_MEMORY_READ_WRITE                    0x0000
#define CM_RESOURCE_MEMORY_READ_ONLY                     0x0001
#define CM_RESOURCE_MEMORY_WRITE_ONLY                    0x0002
#define CM_RESOURCE_MEMORY_WRITEABILITY_MASK             0x0003
#define CM_RESOURCE_MEMORY_PREFETCHABLE                  0x0004
#define CM_RESOURCE_MEMORY_COMBINEDWRITE                 0x0008
#define CM_RESOURCE_MEMORY_24                            0x0010
#define CM_RESOURCE_MEMORY_CACHEABLE                     0x0020
#define CM_RESOURCE_MEMORY_WINDOW_DECODE                 0x0040
#define CM_RESOURCE_MEMORY_BAR                           0x0080
#define CM_RESOURCE_MEMORY_COMPAT_FOR_INACCESSIBLE_RANGE 0x0100

#define CM_RESOURCE_MEMORY_LARGE                         0x0E00
#define CM_RESOURCE_MEMORY_LARGE_40                      0x0200
#define CM_RESOURCE_MEMORY_LARGE_48                      0x0400
#define CM_RESOURCE_MEMORY_LARGE_64                      0x0800

#define CM_RESOURCE_MEMORY_LARGE_40_MAXLEN               0x000000FFFFFFFF00
#define CM_RESOURCE_MEMORY_LARGE_48_MAXLEN               0x0000FFFFFFFF0000
#define CM_RESOURCE_MEMORY_LARGE_64_MAXLEN               0xFFFFFFFF00000000

/* CM_PARTIAL_RESOURCE_DESCRIPTOR.Flags if Type = CmResourceTypeDma */
#define CM_RESOURCE_DMA_8                 0x0000
#define CM_RESOURCE_DMA_16                0x0001
#define CM_RESOURCE_DMA_32                0x0002
#define CM_RESOURCE_DMA_8_AND_16          0x0004
#define CM_RESOURCE_DMA_BUS_MASTER        0x0008
#define CM_RESOURCE_DMA_TYPE_A            0x0010
#define CM_RESOURCE_DMA_TYPE_B            0x0020
#define CM_RESOURCE_DMA_TYPE_F            0x0040

typedef struct _DEVICE_FLAGS {
  ULONG Failed:1;
  ULONG ReadOnly:1;
  ULONG Removable:1;
  ULONG ConsoleIn:1;
  ULONG ConsoleOut:1;
  ULONG Input:1;
  ULONG Output:1;
} DEVICE_FLAGS, *PDEVICE_FLAGS;

typedef enum _INTERFACE_TYPE {
  InterfaceTypeUndefined = -1,
  Internal,
  Isa,
  Eisa,
  MicroChannel,
  TurboChannel,
  PCIBus,
  VMEBus,
  NuBus,
  PCMCIABus,
  CBus,
  MPIBus,
  MPSABus,
  ProcessorInternal,
  InternalPowerBus,
  PNPISABus,
  PNPBus,
  Vmcs,
  MaximumInterfaceType
} INTERFACE_TYPE, *PINTERFACE_TYPE;

typedef struct _CM_COMPONENT_INFORMATION {
  DEVICE_FLAGS Flags;
  ULONG Version;
  ULONG Key;
  KAFFINITY AffinityMask;
} CM_COMPONENT_INFORMATION, *PCM_COMPONENT_INFORMATION;

typedef struct _CM_ROM_BLOCK {
  ULONG Address;
  ULONG Size;
} CM_ROM_BLOCK, *PCM_ROM_BLOCK;

typedef struct _CM_PARTIAL_RESOURCE_LIST {
  USHORT Version;
  USHORT Revision;
  ULONG Count;
  CM_PARTIAL_RESOURCE_DESCRIPTOR PartialDescriptors[1];
} CM_PARTIAL_RESOURCE_LIST, *PCM_PARTIAL_RESOURCE_LIST;

typedef struct _CM_FULL_RESOURCE_DESCRIPTOR {
  INTERFACE_TYPE InterfaceType;
  ULONG BusNumber;
  CM_PARTIAL_RESOURCE_LIST PartialResourceList;
} CM_FULL_RESOURCE_DESCRIPTOR, *PCM_FULL_RESOURCE_DESCRIPTOR;

typedef struct _CM_RESOURCE_LIST {
  ULONG Count;
  CM_FULL_RESOURCE_DESCRIPTOR List[1];
} CM_RESOURCE_LIST, *PCM_RESOURCE_LIST;

typedef struct _PNP_BUS_INFORMATION {
  GUID BusTypeGuid;
  INTERFACE_TYPE LegacyBusType;
  ULONG BusNumber;
} PNP_BUS_INFORMATION, *PPNP_BUS_INFORMATION;

#include <pshpack1.h>

typedef struct _CM_INT13_DRIVE_PARAMETER {
  USHORT DriveSelect;
  ULONG MaxCylinders;
  USHORT SectorsPerTrack;
  USHORT MaxHeads;
  USHORT NumberDrives;
} CM_INT13_DRIVE_PARAMETER, *PCM_INT13_DRIVE_PARAMETER;

typedef struct _CM_MCA_POS_DATA {
  USHORT AdapterId;
  UCHAR PosData1;
  UCHAR PosData2;
  UCHAR PosData3;
  UCHAR PosData4;
} CM_MCA_POS_DATA, *PCM_MCA_POS_DATA;

typedef struct _CM_PNP_BIOS_DEVICE_NODE {
  USHORT Size;
  UCHAR Node;
  ULONG ProductId;
  UCHAR DeviceType[3];
  USHORT DeviceAttributes;
} CM_PNP_BIOS_DEVICE_NODE,*PCM_PNP_BIOS_DEVICE_NODE;

typedef struct _CM_PNP_BIOS_INSTALLATION_CHECK {
  UCHAR Signature[4];
  UCHAR Revision;
  UCHAR Length;
  USHORT ControlField;
  UCHAR Checksum;
  ULONG EventFlagAddress;
  USHORT RealModeEntryOffset;
  USHORT RealModeEntrySegment;
  USHORT ProtectedModeEntryOffset;
  ULONG ProtectedModeCodeBaseAddress;
  ULONG OemDeviceId;
  USHORT RealModeDataBaseAddress;
  ULONG ProtectedModeDataBaseAddress;
} CM_PNP_BIOS_INSTALLATION_CHECK, *PCM_PNP_BIOS_INSTALLATION_CHECK;

#include <poppack.h>

typedef struct _CM_DISK_GEOMETRY_DEVICE_DATA {
  ULONG BytesPerSector;
  ULONG NumberOfCylinders;
  ULONG SectorsPerTrack;
  ULONG NumberOfHeads;
} CM_DISK_GEOMETRY_DEVICE_DATA, *PCM_DISK_GEOMETRY_DEVICE_DATA;

typedef struct _CM_KEYBOARD_DEVICE_DATA {
  USHORT Version;
  USHORT Revision;
  UCHAR Type;
  UCHAR Subtype;
  USHORT KeyboardFlags;
} CM_KEYBOARD_DEVICE_DATA, *PCM_KEYBOARD_DEVICE_DATA;

typedef struct _CM_SCSI_DEVICE_DATA {
  USHORT Version;
  USHORT Revision;
  UCHAR HostIdentifier;
} CM_SCSI_DEVICE_DATA, *PCM_SCSI_DEVICE_DATA;

typedef struct _CM_VIDEO_DEVICE_DATA {
  USHORT Version;
  USHORT Revision;
  ULONG VideoClock;
} CM_VIDEO_DEVICE_DATA, *PCM_VIDEO_DEVICE_DATA;

typedef struct _CM_SONIC_DEVICE_DATA {
  USHORT Version;
  USHORT Revision;
  USHORT DataConfigurationRegister;
  UCHAR EthernetAddress[8];
} CM_SONIC_DEVICE_DATA, *PCM_SONIC_DEVICE_DATA;

typedef struct _CM_SERIAL_DEVICE_DATA {
  USHORT Version;
  USHORT Revision;
  ULONG BaudClock;
} CM_SERIAL_DEVICE_DATA, *PCM_SERIAL_DEVICE_DATA;

typedef struct _CM_MONITOR_DEVICE_DATA {
  USHORT Version;
  USHORT Revision;
  USHORT HorizontalScreenSize;
  USHORT VerticalScreenSize;
  USHORT HorizontalResolution;
  USHORT VerticalResolution;
  USHORT HorizontalDisplayTimeLow;
  USHORT HorizontalDisplayTime;
  USHORT HorizontalDisplayTimeHigh;
  USHORT HorizontalBackPorchLow;
  USHORT HorizontalBackPorch;
  USHORT HorizontalBackPorchHigh;
  USHORT HorizontalFrontPorchLow;
  USHORT HorizontalFrontPorch;
  USHORT HorizontalFrontPorchHigh;
  USHORT HorizontalSyncLow;
  USHORT HorizontalSync;
  USHORT HorizontalSyncHigh;
  USHORT VerticalBackPorchLow;
  USHORT VerticalBackPorch;
  USHORT VerticalBackPorchHigh;
  USHORT VerticalFrontPorchLow;
  USHORT VerticalFrontPorch;
  USHORT VerticalFrontPorchHigh;
  USHORT VerticalSyncLow;
  USHORT VerticalSync;
  USHORT VerticalSyncHigh;
} CM_MONITOR_DEVICE_DATA, *PCM_MONITOR_DEVICE_DATA;

typedef struct _CM_FLOPPY_DEVICE_DATA {
  USHORT Version;
  USHORT Revision;
  CHAR Size[8];
  ULONG MaxDensity;
  ULONG MountDensity;
  UCHAR StepRateHeadUnloadTime;
  UCHAR HeadLoadTime;
  UCHAR MotorOffTime;
  UCHAR SectorLengthCode;
  UCHAR SectorPerTrack;
  UCHAR ReadWriteGapLength;
  UCHAR DataTransferLength;
  UCHAR FormatGapLength;
  UCHAR FormatFillCharacter;
  UCHAR HeadSettleTime;
  UCHAR MotorSettleTime;
  UCHAR MaximumTrackValue;
  UCHAR DataTransferRate;
} CM_FLOPPY_DEVICE_DATA, *PCM_FLOPPY_DEVICE_DATA;

typedef enum _KEY_INFORMATION_CLASS {
  KeyBasicInformation,
  KeyNodeInformation,
  KeyFullInformation,
  KeyNameInformation,
  KeyCachedInformation,
  KeyFlagsInformation,
  KeyVirtualizationInformation,
  KeyHandleTagsInformation,
  MaxKeyInfoClass
} KEY_INFORMATION_CLASS;

typedef struct _KEY_BASIC_INFORMATION {
  LARGE_INTEGER LastWriteTime;
  ULONG TitleIndex;
  ULONG NameLength;
  WCHAR Name[1];
} KEY_BASIC_INFORMATION, *PKEY_BASIC_INFORMATION;

typedef struct _KEY_CONTROL_FLAGS_INFORMATION {
  ULONG ControlFlags;
} KEY_CONTROL_FLAGS_INFORMATION, *PKEY_CONTROL_FLAGS_INFORMATION;

typedef struct _KEY_FULL_INFORMATION {
  LARGE_INTEGER LastWriteTime;
  ULONG TitleIndex;
  ULONG ClassOffset;
  ULONG ClassLength;
  ULONG SubKeys;
  ULONG MaxNameLen;
  ULONG MaxClassLen;
  ULONG Values;
  ULONG MaxValueNameLen;
  ULONG MaxValueDataLen;
  WCHAR Class[1];
} KEY_FULL_INFORMATION, *PKEY_FULL_INFORMATION;

typedef struct _KEY_HANDLE_TAGS_INFORMATION {
  ULONG HandleTags;
} KEY_HANDLE_TAGS_INFORMATION, *PKEY_HANDLE_TAGS_INFORMATION;

typedef struct _KEY_NODE_INFORMATION {
  LARGE_INTEGER LastWriteTime;
  ULONG TitleIndex;
  ULONG ClassOffset;
  ULONG ClassLength;
  ULONG NameLength;
  WCHAR Name[1];
} KEY_NODE_INFORMATION, *PKEY_NODE_INFORMATION;

typedef enum _KEY_SET_INFORMATION_CLASS {
  KeyWriteTimeInformation,
  KeyWow64FlagsInformation,
  KeyControlFlagsInformation,
  KeySetVirtualizationInformation,
  KeySetDebugInformation,
  KeySetHandleTagsInformation,
  MaxKeySetInfoClass
} KEY_SET_INFORMATION_CLASS;

typedef struct _KEY_SET_VIRTUALIZATION_INFORMATION {
  ULONG VirtualTarget:1;
  ULONG VirtualStore:1;
  ULONG VirtualSource:1;
  ULONG Reserved:29;
} KEY_SET_VIRTUALIZATION_INFORMATION, *PKEY_SET_VIRTUALIZATION_INFORMATION;

typedef struct _KEY_VALUE_BASIC_INFORMATION {
  ULONG TitleIndex;
  ULONG Type;
  ULONG NameLength;
  WCHAR Name[1];
} KEY_VALUE_BASIC_INFORMATION, *PKEY_VALUE_BASIC_INFORMATION;

typedef struct _KEY_VALUE_FULL_INFORMATION {
  ULONG TitleIndex;
  ULONG Type;
  ULONG DataOffset;
  ULONG DataLength;
  ULONG NameLength;
  WCHAR Name[1];
} KEY_VALUE_FULL_INFORMATION, *PKEY_VALUE_FULL_INFORMATION;

typedef struct _KEY_VALUE_PARTIAL_INFORMATION {
  ULONG TitleIndex;
  ULONG Type;
  ULONG DataLength;
  UCHAR Data[1];
} KEY_VALUE_PARTIAL_INFORMATION, *PKEY_VALUE_PARTIAL_INFORMATION;

typedef struct _KEY_VALUE_PARTIAL_INFORMATION_ALIGN64 {
  ULONG Type;
  ULONG DataLength;
  UCHAR Data[1];
} KEY_VALUE_PARTIAL_INFORMATION_ALIGN64, *PKEY_VALUE_PARTIAL_INFORMATION_ALIGN64;

typedef struct _KEY_VALUE_ENTRY {
  PUNICODE_STRING ValueName;
  ULONG DataLength;
  ULONG DataOffset;
  ULONG Type;
} KEY_VALUE_ENTRY, *PKEY_VALUE_ENTRY;

typedef enum _KEY_VALUE_INFORMATION_CLASS {
  KeyValueBasicInformation,
  KeyValueFullInformation,
  KeyValuePartialInformation,
  KeyValueFullInformationAlign64,
  KeyValuePartialInformationAlign64
} KEY_VALUE_INFORMATION_CLASS;

typedef struct _KEY_WOW64_FLAGS_INFORMATION {
  ULONG UserFlags;
} KEY_WOW64_FLAGS_INFORMATION, *PKEY_WOW64_FLAGS_INFORMATION;

typedef struct _KEY_WRITE_TIME_INFORMATION {
  LARGE_INTEGER LastWriteTime;
} KEY_WRITE_TIME_INFORMATION, *PKEY_WRITE_TIME_INFORMATION;

typedef enum _REG_NOTIFY_CLASS {
  RegNtDeleteKey,
  RegNtPreDeleteKey = RegNtDeleteKey,
  RegNtSetValueKey,
  RegNtPreSetValueKey = RegNtSetValueKey,
  RegNtDeleteValueKey,
  RegNtPreDeleteValueKey = RegNtDeleteValueKey,
  RegNtSetInformationKey,
  RegNtPreSetInformationKey = RegNtSetInformationKey,
  RegNtRenameKey,
  RegNtPreRenameKey = RegNtRenameKey,
  RegNtEnumerateKey,
  RegNtPreEnumerateKey = RegNtEnumerateKey,
  RegNtEnumerateValueKey,
  RegNtPreEnumerateValueKey = RegNtEnumerateValueKey,
  RegNtQueryKey,
  RegNtPreQueryKey = RegNtQueryKey,
  RegNtQueryValueKey,
  RegNtPreQueryValueKey = RegNtQueryValueKey,
  RegNtQueryMultipleValueKey,
  RegNtPreQueryMultipleValueKey = RegNtQueryMultipleValueKey,
  RegNtPreCreateKey,
  RegNtPostCreateKey,
  RegNtPreOpenKey,
  RegNtPostOpenKey,
  RegNtKeyHandleClose,
  RegNtPreKeyHandleClose = RegNtKeyHandleClose,
  RegNtPostDeleteKey,
  RegNtPostSetValueKey,
  RegNtPostDeleteValueKey,
  RegNtPostSetInformationKey,
  RegNtPostRenameKey,
  RegNtPostEnumerateKey,
  RegNtPostEnumerateValueKey,
  RegNtPostQueryKey,
  RegNtPostQueryValueKey,
  RegNtPostQueryMultipleValueKey,
  RegNtPostKeyHandleClose,
  RegNtPreCreateKeyEx,
  RegNtPostCreateKeyEx,
  RegNtPreOpenKeyEx,
  RegNtPostOpenKeyEx,
  RegNtPreFlushKey,
  RegNtPostFlushKey,
  RegNtPreLoadKey,
  RegNtPostLoadKey,
  RegNtPreUnLoadKey,
  RegNtPostUnLoadKey,
  RegNtPreQueryKeySecurity,
  RegNtPostQueryKeySecurity,
  RegNtPreSetKeySecurity,
  RegNtPostSetKeySecurity,
  RegNtCallbackObjectContextCleanup,
  RegNtPreRestoreKey,
  RegNtPostRestoreKey,
  RegNtPreSaveKey,
  RegNtPostSaveKey,
  RegNtPreReplaceKey,
  RegNtPostReplaceKey,
  MaxRegNtNotifyClass
} REG_NOTIFY_CLASS, *PREG_NOTIFY_CLASS;

typedef NTSTATUS
(NTAPI EX_CALLBACK_FUNCTION)(
  IN PVOID CallbackContext,
  IN PVOID Argument1,
  IN PVOID Argument2);
typedef EX_CALLBACK_FUNCTION *PEX_CALLBACK_FUNCTION;

typedef struct _REG_DELETE_KEY_INFORMATION {
  PVOID Object;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_DELETE_KEY_INFORMATION, *PREG_DELETE_KEY_INFORMATION
#if (NTDDI_VERSION >= NTDDI_VISTA)
, REG_FLUSH_KEY_INFORMATION, *PREG_FLUSH_KEY_INFORMATION
#endif
;

typedef struct _REG_SET_VALUE_KEY_INFORMATION {
  PVOID Object;
  PUNICODE_STRING ValueName;
  ULONG TitleIndex;
  ULONG Type;
  PVOID Data;
  ULONG DataSize;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_SET_VALUE_KEY_INFORMATION, *PREG_SET_VALUE_KEY_INFORMATION;

typedef struct _REG_DELETE_VALUE_KEY_INFORMATION {
  PVOID Object;
  PUNICODE_STRING ValueName;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_DELETE_VALUE_KEY_INFORMATION, *PREG_DELETE_VALUE_KEY_INFORMATION;

typedef struct _REG_SET_INFORMATION_KEY_INFORMATION {
  PVOID Object;
  KEY_SET_INFORMATION_CLASS KeySetInformationClass;
  PVOID KeySetInformation;
  ULONG KeySetInformationLength;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_SET_INFORMATION_KEY_INFORMATION, *PREG_SET_INFORMATION_KEY_INFORMATION;

typedef struct _REG_ENUMERATE_KEY_INFORMATION {
  PVOID Object;
  ULONG Index;
  KEY_INFORMATION_CLASS KeyInformationClass;
  PVOID KeyInformation;
  ULONG Length;
  PULONG ResultLength;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_ENUMERATE_KEY_INFORMATION, *PREG_ENUMERATE_KEY_INFORMATION;

typedef struct _REG_ENUMERATE_VALUE_KEY_INFORMATION {
  PVOID Object;
  ULONG Index;
  KEY_VALUE_INFORMATION_CLASS KeyValueInformationClass;
  PVOID KeyValueInformation;
  ULONG Length;
  PULONG ResultLength;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_ENUMERATE_VALUE_KEY_INFORMATION, *PREG_ENUMERATE_VALUE_KEY_INFORMATION;

typedef struct _REG_QUERY_KEY_INFORMATION {
  PVOID Object;
  KEY_INFORMATION_CLASS KeyInformationClass;
  PVOID KeyInformation;
  ULONG Length;
  PULONG ResultLength;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_QUERY_KEY_INFORMATION, *PREG_QUERY_KEY_INFORMATION;

typedef struct _REG_QUERY_VALUE_KEY_INFORMATION {
  PVOID Object;
  PUNICODE_STRING ValueName;
  KEY_VALUE_INFORMATION_CLASS KeyValueInformationClass;
  PVOID KeyValueInformation;
  ULONG Length;
  PULONG ResultLength;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_QUERY_VALUE_KEY_INFORMATION, *PREG_QUERY_VALUE_KEY_INFORMATION;

typedef struct _REG_QUERY_MULTIPLE_VALUE_KEY_INFORMATION {
  PVOID Object;
  PKEY_VALUE_ENTRY ValueEntries;
  ULONG EntryCount;
  PVOID ValueBuffer;
  PULONG BufferLength;
  PULONG RequiredBufferLength;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_QUERY_MULTIPLE_VALUE_KEY_INFORMATION, *PREG_QUERY_MULTIPLE_VALUE_KEY_INFORMATION;

typedef struct _REG_RENAME_KEY_INFORMATION {
  PVOID Object;
  PUNICODE_STRING NewName;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_RENAME_KEY_INFORMATION, *PREG_RENAME_KEY_INFORMATION;

typedef struct _REG_CREATE_KEY_INFORMATION {
  PUNICODE_STRING CompleteName;
  PVOID RootObject;
  PVOID ObjectType;
  ULONG CreateOptions;
  PUNICODE_STRING Class;
  PVOID SecurityDescriptor;
  PVOID SecurityQualityOfService;
  ACCESS_MASK DesiredAccess;
  ACCESS_MASK GrantedAccess;
  PULONG Disposition;
  PVOID *ResultObject;
  PVOID CallContext;
  PVOID RootObjectContext;
  PVOID Transaction;
  PVOID Reserved;
} REG_CREATE_KEY_INFORMATION, REG_OPEN_KEY_INFORMATION,*PREG_CREATE_KEY_INFORMATION, *PREG_OPEN_KEY_INFORMATION;

typedef struct _REG_CREATE_KEY_INFORMATION_V1 {
  PUNICODE_STRING CompleteName;
  PVOID RootObject;
  PVOID ObjectType;
  ULONG Options;
  PUNICODE_STRING Class;
  PVOID SecurityDescriptor;
  PVOID SecurityQualityOfService;
  ACCESS_MASK DesiredAccess;
  ACCESS_MASK GrantedAccess;
  PULONG Disposition;
  PVOID *ResultObject;
  PVOID CallContext;
  PVOID RootObjectContext;
  PVOID Transaction;
  ULONG_PTR Version;
  PUNICODE_STRING RemainingName;
  ULONG Wow64Flags;
  ULONG Attributes;
  KPROCESSOR_MODE CheckAccessMode;
} REG_CREATE_KEY_INFORMATION_V1, REG_OPEN_KEY_INFORMATION_V1,*PREG_CREATE_KEY_INFORMATION_V1, *PREG_OPEN_KEY_INFORMATION_V1;

typedef struct _REG_PRE_CREATE_KEY_INFORMATION {
  PUNICODE_STRING CompleteName;
} REG_PRE_CREATE_KEY_INFORMATION, REG_PRE_OPEN_KEY_INFORMATION,*PREG_PRE_CREATE_KEY_INFORMATION, *PREG_PRE_OPEN_KEY_INFORMATION;

typedef struct _REG_POST_CREATE_KEY_INFORMATION {
  PUNICODE_STRING CompleteName;
  PVOID Object;
  NTSTATUS Status;
} REG_POST_CREATE_KEY_INFORMATION,REG_POST_OPEN_KEY_INFORMATION, *PREG_POST_CREATE_KEY_INFORMATION, *PREG_POST_OPEN_KEY_INFORMATION;

typedef struct _REG_POST_OPERATION_INFORMATION {
  PVOID Object;
  NTSTATUS Status;
  PVOID PreInformation;
  NTSTATUS ReturnStatus;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_POST_OPERATION_INFORMATION,*PREG_POST_OPERATION_INFORMATION;

typedef struct _REG_KEY_HANDLE_CLOSE_INFORMATION {
  PVOID Object;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_KEY_HANDLE_CLOSE_INFORMATION, *PREG_KEY_HANDLE_CLOSE_INFORMATION;

#if (NTDDI_VERSION >= NTDDI_VISTA)

typedef struct _REG_LOAD_KEY_INFORMATION {
  PVOID Object;
  PUNICODE_STRING KeyName;
  PUNICODE_STRING SourceFile;
  ULONG Flags;
  PVOID TrustClassObject;
  PVOID UserEvent;
  ACCESS_MASK DesiredAccess;
  PHANDLE RootHandle;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_LOAD_KEY_INFORMATION, *PREG_LOAD_KEY_INFORMATION;

typedef struct _REG_UNLOAD_KEY_INFORMATION {
  PVOID Object;
  PVOID UserEvent;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_UNLOAD_KEY_INFORMATION, *PREG_UNLOAD_KEY_INFORMATION;

typedef struct _REG_CALLBACK_CONTEXT_CLEANUP_INFORMATION {
  PVOID Object;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_CALLBACK_CONTEXT_CLEANUP_INFORMATION, *PREG_CALLBACK_CONTEXT_CLEANUP_INFORMATION;

typedef struct _REG_QUERY_KEY_SECURITY_INFORMATION {
  PVOID Object;
  PSECURITY_INFORMATION SecurityInformation;
  PSECURITY_DESCRIPTOR SecurityDescriptor;
  PULONG Length;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_QUERY_KEY_SECURITY_INFORMATION, *PREG_QUERY_KEY_SECURITY_INFORMATION;

typedef struct _REG_SET_KEY_SECURITY_INFORMATION {
  PVOID Object;
  PSECURITY_INFORMATION SecurityInformation;
  PSECURITY_DESCRIPTOR SecurityDescriptor;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_SET_KEY_SECURITY_INFORMATION, *PREG_SET_KEY_SECURITY_INFORMATION;

typedef struct _REG_RESTORE_KEY_INFORMATION {
  PVOID Object;
  HANDLE FileHandle;
  ULONG Flags;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_RESTORE_KEY_INFORMATION, *PREG_RESTORE_KEY_INFORMATION;

typedef struct _REG_SAVE_KEY_INFORMATION {
  PVOID Object;
  HANDLE FileHandle;
  ULONG Format;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_SAVE_KEY_INFORMATION, *PREG_SAVE_KEY_INFORMATION;

typedef struct _REG_REPLACE_KEY_INFORMATION {
  PVOID Object;
  PUNICODE_STRING OldFileName;
  PUNICODE_STRING NewFileName;
  PVOID CallContext;
  PVOID ObjectContext;
  PVOID Reserved;
} REG_REPLACE_KEY_INFORMATION, *PREG_REPLACE_KEY_INFORMATION;

#endif /* NTDDI_VERSION >= NTDDI_VISTA */

#define SERVICE_KERNEL_DRIVER          0x00000001
#define SERVICE_FILE_SYSTEM_DRIVER     0x00000002
#define SERVICE_ADAPTER                0x00000004
#define SERVICE_RECOGNIZER_DRIVER      0x00000008

#define SERVICE_DRIVER                 (SERVICE_KERNEL_DRIVER | \
                                        SERVICE_FILE_SYSTEM_DRIVER | \
                                        SERVICE_RECOGNIZER_DRIVER)

#define SERVICE_WIN32_OWN_PROCESS      0x00000010
#define SERVICE_WIN32_SHARE_PROCESS    0x00000020
#define SERVICE_WIN32                  (SERVICE_WIN32_OWN_PROCESS | \
                                        SERVICE_WIN32_SHARE_PROCESS)

#define SERVICE_INTERACTIVE_PROCESS    0x00000100

#define SERVICE_TYPE_ALL               (SERVICE_WIN32  | \
                                        SERVICE_ADAPTER | \
                                        SERVICE_DRIVER  | \
                                        SERVICE_INTERACTIVE_PROCESS)

/* Service Start Types */
#define SERVICE_BOOT_START             0x00000000
#define SERVICE_SYSTEM_START           0x00000001
#define SERVICE_AUTO_START             0x00000002
#define SERVICE_DEMAND_START           0x00000003
#define SERVICE_DISABLED               0x00000004

#define SERVICE_ERROR_IGNORE           0x00000000
#define SERVICE_ERROR_NORMAL           0x00000001
#define SERVICE_ERROR_SEVERE           0x00000002
#define SERVICE_ERROR_CRITICAL         0x00000003

typedef enum _CM_SERVICE_NODE_TYPE {
  DriverType = SERVICE_KERNEL_DRIVER,
  FileSystemType = SERVICE_FILE_SYSTEM_DRIVER,
  Win32ServiceOwnProcess = SERVICE_WIN32_OWN_PROCESS,
  Win32ServiceShareProcess = SERVICE_WIN32_SHARE_PROCESS,
  AdapterType = SERVICE_ADAPTER,
  RecognizerType = SERVICE_RECOGNIZER_DRIVER
} SERVICE_NODE_TYPE;

typedef enum _CM_SERVICE_LOAD_TYPE {
  BootLoad = SERVICE_BOOT_START,
  SystemLoad = SERVICE_SYSTEM_START,
  AutoLoad = SERVICE_AUTO_START,
  DemandLoad = SERVICE_DEMAND_START,
  DisableLoad = SERVICE_DISABLED
} SERVICE_LOAD_TYPE;

typedef enum _CM_ERROR_CONTROL_TYPE {
  IgnoreError = SERVICE_ERROR_IGNORE,
  NormalError = SERVICE_ERROR_NORMAL,
  SevereError = SERVICE_ERROR_SEVERE,
  CriticalError = SERVICE_ERROR_CRITICAL
} SERVICE_ERROR_TYPE;

#define CM_SERVICE_NETWORK_BOOT_LOAD      0x00000001
#define CM_SERVICE_VIRTUAL_DISK_BOOT_LOAD 0x00000002
#define CM_SERVICE_USB_DISK_BOOT_LOAD     0x00000004

#define CM_SERVICE_VALID_PROMOTION_MASK (CM_SERVICE_NETWORK_BOOT_LOAD |       \
                                         CM_SERVICE_VIRTUAL_DISK_BOOT_LOAD |  \
                                         CM_SERVICE_USB_DISK_BOOT_LOAD)


/******************************************************************************
 *                         I/O Manager Types                                  *
 ******************************************************************************/

#define STATUS_CONTINUE_COMPLETION      STATUS_SUCCESS

#define CONNECT_FULLY_SPECIFIED         0x1
#define CONNECT_LINE_BASED              0x2
#define CONNECT_MESSAGE_BASED           0x3
#define CONNECT_FULLY_SPECIFIED_GROUP   0x4
#define CONNECT_CURRENT_VERSION         0x4

#define POOL_COLD_ALLOCATION                256
#define POOL_QUOTA_FAIL_INSTEAD_OF_RAISE    8
#define POOL_RAISE_IF_ALLOCATION_FAILURE    16

#define IO_TYPE_ADAPTER                 1
#define IO_TYPE_CONTROLLER              2
#define IO_TYPE_DEVICE                  3
#define IO_TYPE_DRIVER                  4
#define IO_TYPE_FILE                    5
#define IO_TYPE_IRP                     6
#define IO_TYPE_MASTER_ADAPTER          7
#define IO_TYPE_OPEN_PACKET             8
#define IO_TYPE_TIMER                   9
#define IO_TYPE_VPB                     10
#define IO_TYPE_ERROR_LOG               11
#define IO_TYPE_ERROR_MESSAGE           12
#define IO_TYPE_DEVICE_OBJECT_EXTENSION 13

#define IO_TYPE_CSQ_IRP_CONTEXT 1
#define IO_TYPE_CSQ 2
#define IO_TYPE_CSQ_EX 3

/* IO_RESOURCE_DESCRIPTOR.Option */
#define IO_RESOURCE_PREFERRED             0x01
#define IO_RESOURCE_DEFAULT               0x02
#define IO_RESOURCE_ALTERNATIVE           0x08

#define FILE_DEVICE_BEEP                  0x00000001
#define FILE_DEVICE_CD_ROM                0x00000002
#define FILE_DEVICE_CD_ROM_FILE_SYSTEM    0x00000003
#define FILE_DEVICE_CONTROLLER            0x00000004
#define FILE_DEVICE_DATALINK              0x00000005
#define FILE_DEVICE_DFS                   0x00000006
#define FILE_DEVICE_DISK                  0x00000007
#define FILE_DEVICE_DISK_FILE_SYSTEM      0x00000008
#define FILE_DEVICE_FILE_SYSTEM           0x00000009
#define FILE_DEVICE_INPORT_PORT           0x0000000a
#define FILE_DEVICE_KEYBOARD              0x0000000b
#define FILE_DEVICE_MAILSLOT              0x0000000c
#define FILE_DEVICE_MIDI_IN               0x0000000d
#define FILE_DEVICE_MIDI_OUT              0x0000000e
#define FILE_DEVICE_MOUSE                 0x0000000f
#define FILE_DEVICE_MULTI_UNC_PROVIDER    0x00000010
#define FILE_DEVICE_NAMED_PIPE            0x00000011
#define FILE_DEVICE_NETWORK               0x00000012
#define FILE_DEVICE_NETWORK_BROWSER       0x00000013
#define FILE_DEVICE_NETWORK_FILE_SYSTEM   0x00000014
#define FILE_DEVICE_NULL                  0x00000015
#define FILE_DEVICE_PARALLEL_PORT         0x00000016
#define FILE_DEVICE_PHYSICAL_NETCARD      0x00000017
#define FILE_DEVICE_PRINTER               0x00000018
#define FILE_DEVICE_SCANNER               0x00000019
#define FILE_DEVICE_SERIAL_MOUSE_PORT     0x0000001a
#define FILE_DEVICE_SERIAL_PORT           0x0000001b
#define FILE_DEVICE_SCREEN                0x0000001c
#define FILE_DEVICE_SOUND                 0x0000001d
#define FILE_DEVICE_STREAMS               0x0000001e
#define FILE_DEVICE_TAPE                  0x0000001f
#define FILE_DEVICE_TAPE_FILE_SYSTEM      0x00000020
#define FILE_DEVICE_TRANSPORT             0x00000021
#define FILE_DEVICE_UNKNOWN               0x00000022
#define FILE_DEVICE_VIDEO                 0x00000023
#define FILE_DEVICE_VIRTUAL_DISK          0x00000024
#define FILE_DEVICE_WAVE_IN               0x00000025
#define FILE_DEVICE_WAVE_OUT              0x00000026
#define FILE_DEVICE_8042_PORT             0x00000027
#define FILE_DEVICE_NETWORK_REDIRECTOR    0x00000028
#define FILE_DEVICE_BATTERY               0x00000029
#define FILE_DEVICE_BUS_EXTENDER          0x0000002a
#define FILE_DEVICE_MODEM                 0x0000002b
#define FILE_DEVICE_VDM                   0x0000002c
#define FILE_DEVICE_MASS_STORAGE          0x0000002d
#define FILE_DEVICE_SMB                   0x0000002e
#define FILE_DEVICE_KS                    0x0000002f
#define FILE_DEVICE_CHANGER               0x00000030
#define FILE_DEVICE_SMARTCARD             0x00000031
#define FILE_DEVICE_ACPI                  0x00000032
#define FILE_DEVICE_DVD                   0x00000033
#define FILE_DEVICE_FULLSCREEN_VIDEO      0x00000034
#define FILE_DEVICE_DFS_FILE_SYSTEM       0x00000035
#define FILE_DEVICE_DFS_VOLUME            0x00000036
#define FILE_DEVICE_SERENUM               0x00000037
#define FILE_DEVICE_TERMSRV               0x00000038
#define FILE_DEVICE_KSEC                  0x00000039
#define FILE_DEVICE_FIPS                  0x0000003A
#define FILE_DEVICE_INFINIBAND            0x0000003B
#define FILE_DEVICE_VMBUS                 0x0000003E
#define FILE_DEVICE_CRYPT_PROVIDER        0x0000003F
#define FILE_DEVICE_WPD                   0x00000040
#define FILE_DEVICE_BLUETOOTH             0x00000041
#define FILE_DEVICE_MT_COMPOSITE          0x00000042
#define FILE_DEVICE_MT_TRANSPORT          0x00000043
#define FILE_DEVICE_BIOMETRIC             0x00000044
#define FILE_DEVICE_PMI                   0x00000045

#if defined(NT_PROCESSOR_GROUPS)

typedef USHORT IRQ_DEVICE_POLICY, *PIRQ_DEVICE_POLICY;

typedef enum _IRQ_DEVICE_POLICY_USHORT {
  IrqPolicyMachineDefault = 0,
  IrqPolicyAllCloseProcessors = 1,
  IrqPolicyOneCloseProcessor = 2,
  IrqPolicyAllProcessorsInMachine = 3,
  IrqPolicyAllProcessorsInGroup = 3,
  IrqPolicySpecifiedProcessors = 4,
  IrqPolicySpreadMessagesAcrossAllProcessors = 5};

#else /* defined(NT_PROCESSOR_GROUPS) */

typedef enum _IRQ_DEVICE_POLICY {
  IrqPolicyMachineDefault = 0,
  IrqPolicyAllCloseProcessors,
  IrqPolicyOneCloseProcessor,
  IrqPolicyAllProcessorsInMachine,
  IrqPolicySpecifiedProcessors,
  IrqPolicySpreadMessagesAcrossAllProcessors
} IRQ_DEVICE_POLICY, *PIRQ_DEVICE_POLICY;

#endif

typedef enum _IRQ_PRIORITY {
  IrqPriorityUndefined = 0,
  IrqPriorityLow,
  IrqPriorityNormal,
  IrqPriorityHigh
} IRQ_PRIORITY, *PIRQ_PRIORITY;

typedef enum _IRQ_GROUP_POLICY {
  GroupAffinityAllGroupZero = 0,
  GroupAffinityDontCare
} IRQ_GROUP_POLICY, *PIRQ_GROUP_POLICY;

#define MAXIMUM_VOLUME_LABEL_LENGTH       (32 * sizeof(WCHAR))

typedef struct _OBJECT_HANDLE_INFORMATION {
  ULONG HandleAttributes;
  ACCESS_MASK GrantedAccess;
} OBJECT_HANDLE_INFORMATION, *POBJECT_HANDLE_INFORMATION;

typedef struct _CLIENT_ID {
  HANDLE UniqueProcess;
  HANDLE UniqueThread;
} CLIENT_ID, *PCLIENT_ID;

typedef struct _VPB {
  CSHORT Type;
  CSHORT Size;
  USHORT Flags;
  USHORT VolumeLabelLength;
  struct _DEVICE_OBJECT *DeviceObject;
  struct _DEVICE_OBJECT *RealDevice;
  ULONG SerialNumber;
  ULONG ReferenceCount;
  WCHAR VolumeLabel[MAXIMUM_VOLUME_LABEL_LENGTH / sizeof(WCHAR)];
} VPB, *PVPB;

typedef enum _IO_ALLOCATION_ACTION {
  KeepObject = 1,
  DeallocateObject,
  DeallocateObjectKeepRegisters
} IO_ALLOCATION_ACTION, *PIO_ALLOCATION_ACTION;

typedef IO_ALLOCATION_ACTION
(NTAPI DRIVER_CONTROL)(
  IN struct _DEVICE_OBJECT *DeviceObject,
  IN struct _IRP *Irp,
  IN PVOID MapRegisterBase,
  IN PVOID Context);
typedef DRIVER_CONTROL *PDRIVER_CONTROL;

typedef struct _WAIT_CONTEXT_BLOCK {
  KDEVICE_QUEUE_ENTRY WaitQueueEntry;
  PDRIVER_CONTROL DeviceRoutine;
  PVOID DeviceContext;
  ULONG NumberOfMapRegisters;
  PVOID DeviceObject;
  PVOID CurrentIrp;
  PKDPC BufferChainingDpc;
} WAIT_CONTEXT_BLOCK, *PWAIT_CONTEXT_BLOCK;

/* DEVICE_OBJECT.Flags */
#define DO_VERIFY_VOLUME                  0x00000002
#define DO_BUFFERED_IO                    0x00000004
#define DO_EXCLUSIVE                      0x00000008
#define DO_DIRECT_IO                      0x00000010
#define DO_MAP_IO_BUFFER                  0x00000020
#define DO_DEVICE_INITIALIZING            0x00000080
#define DO_SHUTDOWN_REGISTERED            0x00000800
#define DO_BUS_ENUMERATED_DEVICE          0x00001000
#define DO_POWER_PAGABLE                  0x00002000
#define DO_POWER_INRUSH                   0x00004000

/* DEVICE_OBJECT.Characteristics */
#define FILE_REMOVABLE_MEDIA              0x00000001
#define FILE_READ_ONLY_DEVICE             0x00000002
#define FILE_FLOPPY_DISKETTE              0x00000004
#define FILE_WRITE_ONCE_MEDIA             0x00000008
#define FILE_REMOTE_DEVICE                0x00000010
#define FILE_DEVICE_IS_MOUNTED            0x00000020
#define FILE_VIRTUAL_VOLUME               0x00000040
#define FILE_AUTOGENERATED_DEVICE_NAME    0x00000080
#define FILE_DEVICE_SECURE_OPEN           0x00000100
#define FILE_CHARACTERISTIC_PNP_DEVICE    0x00000800
#define FILE_CHARACTERISTIC_TS_DEVICE     0x00001000
#define FILE_CHARACTERISTIC_WEBDAV_DEVICE 0x00002000

/* DEVICE_OBJECT.AlignmentRequirement */
#define FILE_BYTE_ALIGNMENT             0x00000000
#define FILE_WORD_ALIGNMENT             0x00000001
#define FILE_LONG_ALIGNMENT             0x00000003
#define FILE_QUAD_ALIGNMENT             0x00000007
#define FILE_OCTA_ALIGNMENT             0x0000000f
#define FILE_32_BYTE_ALIGNMENT          0x0000001f
#define FILE_64_BYTE_ALIGNMENT          0x0000003f
#define FILE_128_BYTE_ALIGNMENT         0x0000007f
#define FILE_256_BYTE_ALIGNMENT         0x000000ff
#define FILE_512_BYTE_ALIGNMENT         0x000001ff

/* DEVICE_OBJECT.DeviceType */
#define DEVICE_TYPE ULONG

typedef struct _DEVICE_OBJECT {
  CSHORT Type;
  USHORT Size;
  LONG ReferenceCount;
  struct _DRIVER_OBJECT *DriverObject;
  struct _DEVICE_OBJECT *NextDevice;
  struct _DEVICE_OBJECT *AttachedDevice;
  struct _IRP *CurrentIrp;
  PIO_TIMER Timer;
  ULONG Flags;
  ULONG Characteristics;
  volatile PVPB Vpb;
  PVOID DeviceExtension;
  DEVICE_TYPE DeviceType;
  CCHAR StackSize;
  union {
    LIST_ENTRY ListEntry;
    WAIT_CONTEXT_BLOCK Wcb;
  } Queue;
  ULONG AlignmentRequirement;
  KDEVICE_QUEUE DeviceQueue;
  KDPC Dpc;
  ULONG ActiveThreadCount;
  PSECURITY_DESCRIPTOR SecurityDescriptor;
  KEVENT DeviceLock;
  USHORT SectorSize;
  USHORT Spare1;
  struct _DEVOBJ_EXTENSION *DeviceObjectExtension;
  PVOID Reserved;
} DEVICE_OBJECT, *PDEVICE_OBJECT;

typedef enum _IO_SESSION_STATE {
  IoSessionStateCreated = 1,
  IoSessionStateInitialized,
  IoSessionStateConnected,
  IoSessionStateDisconnected,
  IoSessionStateDisconnectedLoggedOn,
  IoSessionStateLoggedOn,
  IoSessionStateLoggedOff,
  IoSessionStateTerminated,
  IoSessionStateMax
} IO_SESSION_STATE, *PIO_SESSION_STATE;

typedef enum _IO_COMPLETION_ROUTINE_RESULT {
  ContinueCompletion = STATUS_CONTINUE_COMPLETION,
  StopCompletion = STATUS_MORE_PROCESSING_REQUIRED
} IO_COMPLETION_ROUTINE_RESULT, *PIO_COMPLETION_ROUTINE_RESULT;

typedef struct _IO_INTERRUPT_MESSAGE_INFO_ENTRY {
  PHYSICAL_ADDRESS MessageAddress;
  KAFFINITY TargetProcessorSet;
  PKINTERRUPT InterruptObject;
  ULONG MessageData;
  ULONG Vector;
  KIRQL Irql;
  KINTERRUPT_MODE Mode;
  KINTERRUPT_POLARITY Polarity;
} IO_INTERRUPT_MESSAGE_INFO_ENTRY, *PIO_INTERRUPT_MESSAGE_INFO_ENTRY;

typedef struct _IO_INTERRUPT_MESSAGE_INFO {
  KIRQL UnifiedIrql;
  ULONG MessageCount;
  IO_INTERRUPT_MESSAGE_INFO_ENTRY MessageInfo[1];
} IO_INTERRUPT_MESSAGE_INFO, *PIO_INTERRUPT_MESSAGE_INFO;

typedef struct _IO_CONNECT_INTERRUPT_FULLY_SPECIFIED_PARAMETERS {
  IN PDEVICE_OBJECT PhysicalDeviceObject;
  OUT PKINTERRUPT *InterruptObject;
  IN PKSERVICE_ROUTINE ServiceRoutine;
  IN PVOID ServiceContext;
  IN PKSPIN_LOCK SpinLock OPTIONAL;
  IN KIRQL SynchronizeIrql;
  IN BOOLEAN FloatingSave;
  IN BOOLEAN ShareVector;
  IN ULONG Vector;
  IN KIRQL Irql;
  IN KINTERRUPT_MODE InterruptMode;
  IN KAFFINITY ProcessorEnableMask;
  IN USHORT Group;
} IO_CONNECT_INTERRUPT_FULLY_SPECIFIED_PARAMETERS, *PIO_CONNECT_INTERRUPT_FULLY_SPECIFIED_PARAMETERS;

typedef struct _IO_CONNECT_INTERRUPT_LINE_BASED_PARAMETERS {
  IN PDEVICE_OBJECT PhysicalDeviceObject;
  OUT PKINTERRUPT *InterruptObject;
  IN PKSERVICE_ROUTINE ServiceRoutine;
  IN PVOID ServiceContext;
  IN PKSPIN_LOCK SpinLock OPTIONAL;
  IN KIRQL SynchronizeIrql OPTIONAL;
  IN BOOLEAN FloatingSave;
} IO_CONNECT_INTERRUPT_LINE_BASED_PARAMETERS, *PIO_CONNECT_INTERRUPT_LINE_BASED_PARAMETERS;

typedef struct _IO_CONNECT_INTERRUPT_MESSAGE_BASED_PARAMETERS {
  IN PDEVICE_OBJECT PhysicalDeviceObject;
  union {
    OUT PVOID *Generic;
    OUT PIO_INTERRUPT_MESSAGE_INFO *InterruptMessageTable;
    OUT PKINTERRUPT *InterruptObject;
  } ConnectionContext;
  IN PKMESSAGE_SERVICE_ROUTINE MessageServiceRoutine;
  IN PVOID ServiceContext;
  IN PKSPIN_LOCK SpinLock OPTIONAL;
  IN KIRQL SynchronizeIrql OPTIONAL;
  IN BOOLEAN FloatingSave;
  IN PKSERVICE_ROUTINE FallBackServiceRoutine OPTIONAL;
} IO_CONNECT_INTERRUPT_MESSAGE_BASED_PARAMETERS, *PIO_CONNECT_INTERRUPT_MESSAGE_BASED_PARAMETERS;

typedef struct _IO_CONNECT_INTERRUPT_PARAMETERS {
  IN OUT ULONG Version;
  _ANONYMOUS_UNION union {
    IO_CONNECT_INTERRUPT_FULLY_SPECIFIED_PARAMETERS FullySpecified;
    IO_CONNECT_INTERRUPT_LINE_BASED_PARAMETERS LineBased;
    IO_CONNECT_INTERRUPT_MESSAGE_BASED_PARAMETERS MessageBased;
  } DUMMYUNIONNAME;
} IO_CONNECT_INTERRUPT_PARAMETERS, *PIO_CONNECT_INTERRUPT_PARAMETERS;

typedef struct _IO_DISCONNECT_INTERRUPT_PARAMETERS {
  IN ULONG Version;
  union {
    IN PVOID Generic;
    IN PKINTERRUPT InterruptObject;
    IN PIO_INTERRUPT_MESSAGE_INFO InterruptMessageTable;
  } ConnectionContext;
} IO_DISCONNECT_INTERRUPT_PARAMETERS, *PIO_DISCONNECT_INTERRUPT_PARAMETERS;

typedef enum _IO_ACCESS_TYPE {
  ReadAccess,
  WriteAccess,
  ModifyAccess
} IO_ACCESS_TYPE;

typedef enum _IO_ACCESS_MODE {
  SequentialAccess,
  RandomAccess
} IO_ACCESS_MODE;

typedef enum _IO_CONTAINER_NOTIFICATION_CLASS {
  IoSessionStateNotification,
  IoMaxContainerNotificationClass
} IO_CONTAINER_NOTIFICATION_CLASS;

typedef struct _IO_SESSION_STATE_NOTIFICATION {
  ULONG Size;
  ULONG Flags;
  PVOID IoObject;
  ULONG EventMask;
  PVOID Context;
} IO_SESSION_STATE_NOTIFICATION, *PIO_SESSION_STATE_NOTIFICATION;

typedef enum _IO_CONTAINER_INFORMATION_CLASS {
  IoSessionStateInformation,
  IoMaxContainerInformationClass
} IO_CONTAINER_INFORMATION_CLASS;

typedef struct _IO_SESSION_STATE_INFORMATION {
  ULONG SessionId;
  IO_SESSION_STATE SessionState;
  BOOLEAN LocalSession;
} IO_SESSION_STATE_INFORMATION, *PIO_SESSION_STATE_INFORMATION;

#if (NTDDI_VERSION >= NTDDI_WIN7)

typedef NTSTATUS
(NTAPI *PIO_CONTAINER_NOTIFICATION_FUNCTION)(
  VOID);

typedef NTSTATUS
(NTAPI IO_SESSION_NOTIFICATION_FUNCTION)(
  IN PVOID SessionObject,
  IN PVOID IoObject,
  IN ULONG Event,
  IN PVOID Context,
  IN PVOID NotificationPayload,
  IN ULONG PayloadLength);

typedef IO_SESSION_NOTIFICATION_FUNCTION *PIO_SESSION_NOTIFICATION_FUNCTION;

#endif

typedef struct _IO_REMOVE_LOCK_TRACKING_BLOCK * PIO_REMOVE_LOCK_TRACKING_BLOCK;

typedef struct _IO_REMOVE_LOCK_COMMON_BLOCK {
  BOOLEAN Removed;
  BOOLEAN Reserved[3];
  volatile LONG IoCount;
  KEVENT RemoveEvent;
} IO_REMOVE_LOCK_COMMON_BLOCK;

typedef struct _IO_REMOVE_LOCK_DBG_BLOCK {
  LONG Signature;
  LONG HighWatermark;
  LONGLONG MaxLockedTicks;
  LONG AllocateTag;
  LIST_ENTRY LockList;
  KSPIN_LOCK Spin;
  volatile LONG LowMemoryCount;
  ULONG Reserved1[4];
  PVOID Reserved2;
  PIO_REMOVE_LOCK_TRACKING_BLOCK Blocks;
} IO_REMOVE_LOCK_DBG_BLOCK;

typedef struct _IO_REMOVE_LOCK {
  IO_REMOVE_LOCK_COMMON_BLOCK Common;
#if DBG
  IO_REMOVE_LOCK_DBG_BLOCK Dbg;
#endif
} IO_REMOVE_LOCK, *PIO_REMOVE_LOCK;

typedef struct _IO_WORKITEM *PIO_WORKITEM;

typedef VOID
(NTAPI IO_WORKITEM_ROUTINE)(
  IN PDEVICE_OBJECT DeviceObject,
  IN PVOID Context);
typedef IO_WORKITEM_ROUTINE *PIO_WORKITEM_ROUTINE;

typedef VOID
(NTAPI IO_WORKITEM_ROUTINE_EX)(
  IN PVOID IoObject,
  IN PVOID Context OPTIONAL,
  IN PIO_WORKITEM IoWorkItem);
typedef IO_WORKITEM_ROUTINE_EX *PIO_WORKITEM_ROUTINE_EX;

typedef struct _SHARE_ACCESS {
  ULONG OpenCount;
  ULONG Readers;
  ULONG Writers;
  ULONG Deleters;
  ULONG SharedRead;
  ULONG SharedWrite;
  ULONG SharedDelete;
} SHARE_ACCESS, *PSHARE_ACCESS;

/* While MS WDK uses inheritance in C++, we cannot do this with gcc, as
   inheritance, even from a struct renders the type non-POD. So we use
   this hack */
#define PCI_COMMON_HEADER_LAYOUT                \
  USHORT VendorID;                              \
  USHORT DeviceID;                              \
  USHORT Command;                               \
  USHORT Status;                                \
  UCHAR RevisionID;                             \
  UCHAR ProgIf;                                 \
  UCHAR SubClass;                               \
  UCHAR BaseClass;                              \
  UCHAR CacheLineSize;                          \
  UCHAR LatencyTimer;                           \
  UCHAR HeaderType;                             \
  UCHAR BIST;                                   \
  union {                                       \
    struct /* _PCI_HEADER_TYPE_0 */ {                 \
      ULONG BaseAddresses[PCI_TYPE0_ADDRESSES]; \
      ULONG CIS;                                \
      USHORT SubVendorID;                       \
      USHORT SubSystemID;                       \
      ULONG ROMBaseAddress;                     \
      UCHAR CapabilitiesPtr;                    \
      UCHAR Reserved1[3];                       \
      ULONG Reserved2;                          \
      UCHAR InterruptLine;                      \
      UCHAR InterruptPin;                       \
      UCHAR MinimumGrant;                       \
      UCHAR MaximumLatency;                     \
    } type0;                                    \
    struct /* _PCI_HEADER_TYPE_1 */ {                 \
      ULONG BaseAddresses[PCI_TYPE1_ADDRESSES]; \
      UCHAR PrimaryBus;                         \
      UCHAR SecondaryBus;                       \
      UCHAR SubordinateBus;                     \
      UCHAR SecondaryLatency;                   \
      UCHAR IOBase;                             \
      UCHAR IOLimit;                            \
      USHORT SecondaryStatus;                   \
      USHORT MemoryBase;                        \
      USHORT MemoryLimit;                       \
      USHORT PrefetchBase;                      \
      USHORT PrefetchLimit;                     \
      ULONG PrefetchBaseUpper32;                \
      ULONG PrefetchLimitUpper32;               \
      USHORT IOBaseUpper16;                     \
      USHORT IOLimitUpper16;                    \
      UCHAR CapabilitiesPtr;                    \
      UCHAR Reserved1[3];                       \
      ULONG ROMBaseAddress;                     \
      UCHAR InterruptLine;                      \
      UCHAR InterruptPin;                       \
      USHORT BridgeControl;                     \
    } type1;                                    \
    struct /* _PCI_HEADER_TYPE_2 */ {                 \
      ULONG SocketRegistersBaseAddress;         \
      UCHAR CapabilitiesPtr;                    \
      UCHAR Reserved;                           \
      USHORT SecondaryStatus;                   \
      UCHAR PrimaryBus;                         \
      UCHAR SecondaryBus;                       \
      UCHAR SubordinateBus;                     \
      UCHAR SecondaryLatency;                   \
      struct {                                  \
        ULONG Base;                             \
        ULONG Limit;                            \
      } Range[PCI_TYPE2_ADDRESSES-1];           \
      UCHAR InterruptLine;                      \
      UCHAR InterruptPin;                       \
      USHORT BridgeControl;                     \
    } type2;                                    \
  } u;

typedef enum _CREATE_FILE_TYPE {
  CreateFileTypeNone,
  CreateFileTypeNamedPipe,
  CreateFileTypeMailslot
} CREATE_FILE_TYPE;

#define IO_FORCE_ACCESS_CHECK               0x001
#define IO_NO_PARAMETER_CHECKING            0x100

#define IO_REPARSE                      0x0
#define IO_REMOUNT                      0x1

typedef struct _IO_STATUS_BLOCK {
  _ANONYMOUS_UNION union {
    NTSTATUS Status;
    PVOID Pointer;
  } DUMMYUNIONNAME;
  ULONG_PTR Information;
} IO_STATUS_BLOCK, *PIO_STATUS_BLOCK;

#if defined(_WIN64)
typedef struct _IO_STATUS_BLOCK32 {
  NTSTATUS Status;
  ULONG Information;
} IO_STATUS_BLOCK32, *PIO_STATUS_BLOCK32;
#endif

typedef VOID
(NTAPI *PIO_APC_ROUTINE)(
  IN PVOID ApcContext,
  IN PIO_STATUS_BLOCK IoStatusBlock,
  IN ULONG Reserved);

#define PIO_APC_ROUTINE_DEFINED

typedef enum _IO_SESSION_EVENT {
  IoSessionEventIgnore = 0,
  IoSessionEventCreated,
  IoSessionEventTerminated,
  IoSessionEventConnected,
  IoSessionEventDisconnected,
  IoSessionEventLogon,
  IoSessionEventLogoff,
  IoSessionEventMax
} IO_SESSION_EVENT, *PIO_SESSION_EVENT;

#define IO_SESSION_STATE_ALL_EVENTS        0xffffffff
#define IO_SESSION_STATE_CREATION_EVENT    0x00000001
#define IO_SESSION_STATE_TERMINATION_EVENT 0x00000002
#define IO_SESSION_STATE_CONNECT_EVENT     0x00000004
#define IO_SESSION_STATE_DISCONNECT_EVENT  0x00000008
#define IO_SESSION_STATE_LOGON_EVENT       0x00000010
#define IO_SESSION_STATE_LOGOFF_EVENT      0x00000020

#define IO_SESSION_STATE_VALID_EVENT_MASK  0x0000003f

#define IO_SESSION_MAX_PAYLOAD_SIZE        256L

typedef struct _IO_SESSION_CONNECT_INFO {
  ULONG SessionId;
  BOOLEAN LocalSession;
} IO_SESSION_CONNECT_INFO, *PIO_SESSION_CONNECT_INFO;

#define EVENT_INCREMENT                   1
#define IO_NO_INCREMENT                   0
#define IO_CD_ROM_INCREMENT               1
#define IO_DISK_INCREMENT                 1
#define IO_KEYBOARD_INCREMENT             6
#define IO_MAILSLOT_INCREMENT             2
#define IO_MOUSE_INCREMENT                6
#define IO_NAMED_PIPE_INCREMENT           2
#define IO_NETWORK_INCREMENT              2
#define IO_PARALLEL_INCREMENT             1
#define IO_SERIAL_INCREMENT               2
#define IO_SOUND_INCREMENT                8
#define IO_VIDEO_INCREMENT                1
#define SEMAPHORE_INCREMENT               1

#define MM_MAXIMUM_DISK_IO_SIZE          (0x10000)

typedef struct _BOOTDISK_INFORMATION {
  LONGLONG BootPartitionOffset;
  LONGLONG SystemPartitionOffset;
  ULONG BootDeviceSignature;
  ULONG SystemDeviceSignature;
} BOOTDISK_INFORMATION, *PBOOTDISK_INFORMATION;

typedef struct _BOOTDISK_INFORMATION_EX {
  LONGLONG BootPartitionOffset;
  LONGLONG SystemPartitionOffset;
  ULONG BootDeviceSignature;
  ULONG SystemDeviceSignature;
  GUID BootDeviceGuid;
  GUID SystemDeviceGuid;
  BOOLEAN BootDeviceIsGpt;
  BOOLEAN SystemDeviceIsGpt;
} BOOTDISK_INFORMATION_EX, *PBOOTDISK_INFORMATION_EX;

#if (NTDDI_VERSION >= NTDDI_WIN7)

typedef struct _LOADER_PARTITION_INFORMATION_EX {
  ULONG PartitionStyle;
  ULONG PartitionNumber;
  _ANONYMOUS_UNION union {
    ULONG Signature;
    GUID DeviceId;
  } DUMMYUNIONNAME;
  ULONG Flags;
} LOADER_PARTITION_INFORMATION_EX, *PLOADER_PARTITION_INFORMATION_EX;

typedef struct _BOOTDISK_INFORMATION_LITE {
  ULONG NumberEntries;
  LOADER_PARTITION_INFORMATION_EX Entries[1];
} BOOTDISK_INFORMATION_LITE, *PBOOTDISK_INFORMATION_LITE;

#else

#if (NTDDI_VERSION >= NTDDI_VISTA)
typedef struct _BOOTDISK_INFORMATION_LITE {
  ULONG BootDeviceSignature;
  ULONG SystemDeviceSignature;
  GUID BootDeviceGuid;
  GUID SystemDeviceGuid;
  BOOLEAN BootDeviceIsGpt;
  BOOLEAN SystemDeviceIsGpt;
} BOOTDISK_INFORMATION_LITE, *PBOOTDISK_INFORMATION_LITE;
#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#endif /* (NTDDI_VERSION >= NTDDI_WIN7) */

#include <pshpack1.h>

typedef struct _EISA_MEMORY_TYPE {
  UCHAR ReadWrite:1;
  UCHAR Cached:1;
  UCHAR Reserved0:1;
  UCHAR Type:2;
  UCHAR Shared:1;
  UCHAR Reserved1:1;
  UCHAR MoreEntries:1;
} EISA_MEMORY_TYPE, *PEISA_MEMORY_TYPE;

typedef struct _EISA_MEMORY_CONFIGURATION {
  EISA_MEMORY_TYPE ConfigurationByte;
  UCHAR DataSize;
  USHORT AddressLowWord;
  UCHAR AddressHighByte;
  USHORT MemorySize;
} EISA_MEMORY_CONFIGURATION, *PEISA_MEMORY_CONFIGURATION;

typedef struct _EISA_IRQ_DESCRIPTOR {
  UCHAR Interrupt:4;
  UCHAR Reserved:1;
  UCHAR LevelTriggered:1;
  UCHAR Shared:1;
  UCHAR MoreEntries:1;
} EISA_IRQ_DESCRIPTOR, *PEISA_IRQ_DESCRIPTOR;

typedef struct _EISA_IRQ_CONFIGURATION {
  EISA_IRQ_DESCRIPTOR ConfigurationByte;
  UCHAR Reserved;
} EISA_IRQ_CONFIGURATION, *PEISA_IRQ_CONFIGURATION;

typedef struct _DMA_CONFIGURATION_BYTE0 {
  UCHAR Channel:3;
  UCHAR Reserved:3;
  UCHAR Shared:1;
  UCHAR MoreEntries:1;
} DMA_CONFIGURATION_BYTE0;

typedef struct _DMA_CONFIGURATION_BYTE1 {
  UCHAR Reserved0:2;
  UCHAR TransferSize:2;
  UCHAR Timing:2;
  UCHAR Reserved1:2;
} DMA_CONFIGURATION_BYTE1;

typedef struct _EISA_DMA_CONFIGURATION {
  DMA_CONFIGURATION_BYTE0 ConfigurationByte0;
  DMA_CONFIGURATION_BYTE1 ConfigurationByte1;
} EISA_DMA_CONFIGURATION, *PEISA_DMA_CONFIGURATION;

typedef struct _EISA_PORT_DESCRIPTOR {
  UCHAR NumberPorts:5;
  UCHAR Reserved:1;
  UCHAR Shared:1;
  UCHAR MoreEntries:1;
} EISA_PORT_DESCRIPTOR, *PEISA_PORT_DESCRIPTOR;

typedef struct _EISA_PORT_CONFIGURATION {
  EISA_PORT_DESCRIPTOR Configuration;
  USHORT PortAddress;
} EISA_PORT_CONFIGURATION, *PEISA_PORT_CONFIGURATION;

typedef struct _CM_EISA_SLOT_INFORMATION {
  UCHAR ReturnCode;
  UCHAR ReturnFlags;
  UCHAR MajorRevision;
  UCHAR MinorRevision;
  USHORT Checksum;
  UCHAR NumberFunctions;
  UCHAR FunctionInformation;
  ULONG CompressedId;
} CM_EISA_SLOT_INFORMATION, *PCM_EISA_SLOT_INFORMATION;

typedef struct _CM_EISA_FUNCTION_INFORMATION {
  ULONG CompressedId;
  UCHAR IdSlotFlags1;
  UCHAR IdSlotFlags2;
  UCHAR MinorRevision;
  UCHAR MajorRevision;
  UCHAR Selections[26];
  UCHAR FunctionFlags;
  UCHAR TypeString[80];
  EISA_MEMORY_CONFIGURATION EisaMemory[9];
  EISA_IRQ_CONFIGURATION EisaIrq[7];
  EISA_DMA_CONFIGURATION EisaDma[4];
  EISA_PORT_CONFIGURATION EisaPort[20];
  UCHAR InitializationData[60];
} CM_EISA_FUNCTION_INFORMATION, *PCM_EISA_FUNCTION_INFORMATION;

#include <poppack.h>

/* CM_EISA_FUNCTION_INFORMATION.FunctionFlags */

#define EISA_FUNCTION_ENABLED           0x80
#define EISA_FREE_FORM_DATA             0x40
#define EISA_HAS_PORT_INIT_ENTRY        0x20
#define EISA_HAS_PORT_RANGE             0x10
#define EISA_HAS_DMA_ENTRY              0x08
#define EISA_HAS_IRQ_ENTRY              0x04
#define EISA_HAS_MEMORY_ENTRY           0x02
#define EISA_HAS_TYPE_ENTRY             0x01
#define EISA_HAS_INFORMATION \
  (EISA_HAS_PORT_RANGE + EISA_HAS_DMA_ENTRY + EISA_HAS_IRQ_ENTRY \
  + EISA_HAS_MEMORY_ENTRY + EISA_HAS_TYPE_ENTRY)

#define EISA_MORE_ENTRIES               0x80
#define EISA_SYSTEM_MEMORY              0x00
#define EISA_MEMORY_TYPE_RAM            0x01

/* CM_EISA_SLOT_INFORMATION.ReturnCode */

#define EISA_INVALID_SLOT               0x80
#define EISA_INVALID_FUNCTION           0x81
#define EISA_INVALID_CONFIGURATION      0x82
#define EISA_EMPTY_SLOT                 0x83
#define EISA_INVALID_BIOS_CALL          0x86

/*
** Plug and Play structures
*/

typedef VOID
(NTAPI *PINTERFACE_REFERENCE)(
  PVOID Context);

typedef VOID
(NTAPI *PINTERFACE_DEREFERENCE)(
  PVOID Context);

typedef BOOLEAN
(NTAPI TRANSLATE_BUS_ADDRESS)(
  IN PVOID Context,
  IN PHYSICAL_ADDRESS BusAddress,
  IN ULONG Length,
  IN OUT PULONG AddressSpace,
  OUT PPHYSICAL_ADDRESS  TranslatedAddress);
typedef TRANSLATE_BUS_ADDRESS *PTRANSLATE_BUS_ADDRESS;

typedef struct _DMA_ADAPTER*
(NTAPI GET_DMA_ADAPTER)(
  IN PVOID Context,
  IN struct _DEVICE_DESCRIPTION *DeviceDescriptor,
  OUT PULONG NumberOfMapRegisters);
typedef GET_DMA_ADAPTER *PGET_DMA_ADAPTER;

typedef ULONG
(NTAPI GET_SET_DEVICE_DATA)(
  IN PVOID Context,
  IN ULONG DataType,
  IN PVOID Buffer,
  IN ULONG Offset,
  IN ULONG Length);
typedef GET_SET_DEVICE_DATA *PGET_SET_DEVICE_DATA;

typedef enum _DEVICE_INSTALL_STATE {
  InstallStateInstalled,
  InstallStateNeedsReinstall,
  InstallStateFailedInstall,
  InstallStateFinishInstall
} DEVICE_INSTALL_STATE, *PDEVICE_INSTALL_STATE;

typedef struct _LEGACY_BUS_INFORMATION {
  GUID BusTypeGuid;
  INTERFACE_TYPE LegacyBusType;
  ULONG BusNumber;
} LEGACY_BUS_INFORMATION, *PLEGACY_BUS_INFORMATION;

typedef enum _DEVICE_REMOVAL_POLICY {
  RemovalPolicyExpectNoRemoval = 1,
  RemovalPolicyExpectOrderlyRemoval = 2,
  RemovalPolicyExpectSurpriseRemoval = 3
} DEVICE_REMOVAL_POLICY, *PDEVICE_REMOVAL_POLICY;

typedef VOID
(NTAPI*PREENUMERATE_SELF)(
  IN PVOID Context);

typedef struct _REENUMERATE_SELF_INTERFACE_STANDARD {
  USHORT Size;
  USHORT Version;
  PVOID Context;
  PINTERFACE_REFERENCE InterfaceReference;
  PINTERFACE_DEREFERENCE InterfaceDereference;
  PREENUMERATE_SELF SurpriseRemoveAndReenumerateSelf;
} REENUMERATE_SELF_INTERFACE_STANDARD, *PREENUMERATE_SELF_INTERFACE_STANDARD;

typedef VOID
(NTAPI *PIO_DEVICE_EJECT_CALLBACK)(
  IN NTSTATUS Status,
  IN OUT PVOID Context OPTIONAL);

#define PCI_DEVICE_PRESENT_INTERFACE_VERSION     1

/* PCI_DEVICE_PRESENCE_PARAMETERS.Flags */
#define PCI_USE_SUBSYSTEM_IDS   0x00000001
#define PCI_USE_REVISION        0x00000002
#define PCI_USE_VENDEV_IDS      0x00000004
#define PCI_USE_CLASS_SUBCLASS  0x00000008
#define PCI_USE_PROGIF          0x00000010
#define PCI_USE_LOCAL_BUS       0x00000020
#define PCI_USE_LOCAL_DEVICE    0x00000040

typedef struct _PCI_DEVICE_PRESENCE_PARAMETERS {
  ULONG Size;
  ULONG Flags;
  USHORT VendorID;
  USHORT DeviceID;
  UCHAR RevisionID;
  USHORT SubVendorID;
  USHORT SubSystemID;
  UCHAR BaseClass;
  UCHAR SubClass;
  UCHAR ProgIf;
} PCI_DEVICE_PRESENCE_PARAMETERS, *PPCI_DEVICE_PRESENCE_PARAMETERS;

typedef BOOLEAN
(NTAPI PCI_IS_DEVICE_PRESENT)(
  IN USHORT VendorID,
  IN USHORT DeviceID,
  IN UCHAR RevisionID,
  IN USHORT SubVendorID,
  IN USHORT SubSystemID,
  IN ULONG Flags);
typedef PCI_IS_DEVICE_PRESENT *PPCI_IS_DEVICE_PRESENT;

typedef BOOLEAN
(NTAPI PCI_IS_DEVICE_PRESENT_EX)(
  IN PVOID Context,
  IN PPCI_DEVICE_PRESENCE_PARAMETERS Parameters);
typedef PCI_IS_DEVICE_PRESENT_EX *PPCI_IS_DEVICE_PRESENT_EX;

typedef struct _BUS_INTERFACE_STANDARD {
  USHORT Size;
  USHORT Version;
  PVOID Context;
  PINTERFACE_REFERENCE InterfaceReference;
  PINTERFACE_DEREFERENCE InterfaceDereference;
  PTRANSLATE_BUS_ADDRESS TranslateBusAddress;
  PGET_DMA_ADAPTER GetDmaAdapter;
  PGET_SET_DEVICE_DATA SetBusData;
  PGET_SET_DEVICE_DATA GetBusData;
} BUS_INTERFACE_STANDARD, *PBUS_INTERFACE_STANDARD;

typedef struct _PCI_DEVICE_PRESENT_INTERFACE {
  USHORT Size;
  USHORT Version;
  PVOID Context;
  PINTERFACE_REFERENCE InterfaceReference;
  PINTERFACE_DEREFERENCE InterfaceDereference;
  PPCI_IS_DEVICE_PRESENT IsDevicePresent;
  PPCI_IS_DEVICE_PRESENT_EX IsDevicePresentEx;
} PCI_DEVICE_PRESENT_INTERFACE, *PPCI_DEVICE_PRESENT_INTERFACE;

typedef struct _DEVICE_CAPABILITIES {
  USHORT Size;
  USHORT Version;
  ULONG DeviceD1:1;
  ULONG DeviceD2:1;
  ULONG LockSupported:1;
  ULONG EjectSupported:1;
  ULONG Removable:1;
  ULONG DockDevice:1;
  ULONG UniqueID:1;
  ULONG SilentInstall:1;
  ULONG RawDeviceOK:1;
  ULONG SurpriseRemovalOK:1;
  ULONG WakeFromD0:1;
  ULONG WakeFromD1:1;
  ULONG WakeFromD2:1;
  ULONG WakeFromD3:1;
  ULONG HardwareDisabled:1;
  ULONG NonDynamic:1;
  ULONG WarmEjectSupported:1;
  ULONG NoDisplayInUI:1;
  ULONG Reserved:14;
  ULONG Address;
  ULONG UINumber;
  DEVICE_POWER_STATE DeviceState[PowerSystemMaximum];
  SYSTEM_POWER_STATE SystemWake;
  DEVICE_POWER_STATE DeviceWake;
  ULONG D1Latency;
  ULONG D2Latency;
  ULONG D3Latency;
} DEVICE_CAPABILITIES, *PDEVICE_CAPABILITIES;

typedef struct _DEVICE_INTERFACE_CHANGE_NOTIFICATION {
  USHORT Version;
  USHORT Size;
  GUID Event;
  GUID InterfaceClassGuid;
  PUNICODE_STRING SymbolicLinkName;
} DEVICE_INTERFACE_CHANGE_NOTIFICATION, *PDEVICE_INTERFACE_CHANGE_NOTIFICATION;

typedef struct _HWPROFILE_CHANGE_NOTIFICATION {
  USHORT Version;
  USHORT Size;
  GUID Event;
} HWPROFILE_CHANGE_NOTIFICATION, *PHWPROFILE_CHANGE_NOTIFICATION;

#undef INTERFACE

typedef struct _INTERFACE {
  USHORT Size;
  USHORT Version;
  PVOID Context;
  PINTERFACE_REFERENCE InterfaceReference;
  PINTERFACE_DEREFERENCE InterfaceDereference;
} INTERFACE, *PINTERFACE;

typedef struct _PLUGPLAY_NOTIFICATION_HEADER {
  USHORT Version;
  USHORT Size;
  GUID Event;
} PLUGPLAY_NOTIFICATION_HEADER, *PPLUGPLAY_NOTIFICATION_HEADER;

typedef ULONG PNP_DEVICE_STATE, *PPNP_DEVICE_STATE;

/* PNP_DEVICE_STATE */

#define PNP_DEVICE_DISABLED                      0x00000001
#define PNP_DEVICE_DONT_DISPLAY_IN_UI            0x00000002
#define PNP_DEVICE_FAILED                        0x00000004
#define PNP_DEVICE_REMOVED                       0x00000008
#define PNP_DEVICE_RESOURCE_REQUIREMENTS_CHANGED 0x00000010
#define PNP_DEVICE_NOT_DISABLEABLE               0x00000020

typedef struct _TARGET_DEVICE_CUSTOM_NOTIFICATION {
  USHORT Version;
  USHORT Size;
  GUID Event;
  struct _FILE_OBJECT *FileObject;
  LONG NameBufferOffset;
  UCHAR CustomDataBuffer[1];
} TARGET_DEVICE_CUSTOM_NOTIFICATION, *PTARGET_DEVICE_CUSTOM_NOTIFICATION;

typedef struct _TARGET_DEVICE_REMOVAL_NOTIFICATION {
  USHORT Version;
  USHORT Size;
  GUID Event;
  struct _FILE_OBJECT *FileObject;
} TARGET_DEVICE_REMOVAL_NOTIFICATION, *PTARGET_DEVICE_REMOVAL_NOTIFICATION;

#if (NTDDI_VERSION >= NTDDI_VISTA)
#include <devpropdef.h>
#define PLUGPLAY_PROPERTY_PERSISTENT   0x00000001
#endif

#define PNP_REPLACE_NO_MAP             MAXLONGLONG

typedef NTSTATUS
(NTAPI *PREPLACE_MAP_MEMORY)(
  IN PHYSICAL_ADDRESS TargetPhysicalAddress,
  IN PHYSICAL_ADDRESS SparePhysicalAddress,
  IN OUT PLARGE_INTEGER NumberOfBytes,
  OUT PVOID *TargetAddress,
  OUT PVOID *SpareAddress);

typedef struct _PNP_REPLACE_MEMORY_LIST {
  ULONG AllocatedCount;
  ULONG Count;
  ULONGLONG TotalLength;
  struct {
    PHYSICAL_ADDRESS Address;
    ULONGLONG Length;
  } Ranges[ANYSIZE_ARRAY];
} PNP_REPLACE_MEMORY_LIST, *PPNP_REPLACE_MEMORY_LIST;

typedef struct _PNP_REPLACE_PROCESSOR_LIST {
  PKAFFINITY Affinity;
  ULONG GroupCount;
  ULONG AllocatedCount;
  ULONG Count;
  ULONG ApicIds[ANYSIZE_ARRAY];
} PNP_REPLACE_PROCESSOR_LIST, *PPNP_REPLACE_PROCESSOR_LIST;

typedef struct _PNP_REPLACE_PROCESSOR_LIST_V1 {
  KAFFINITY AffinityMask;
  ULONG AllocatedCount;
  ULONG Count;
  ULONG ApicIds[ANYSIZE_ARRAY];
} PNP_REPLACE_PROCESSOR_LIST_V1, *PPNP_REPLACE_PROCESSOR_LIST_V1;

#define PNP_REPLACE_PARAMETERS_VERSION           2

typedef struct _PNP_REPLACE_PARAMETERS {
  ULONG Size;
  ULONG Version;
  ULONG64 Target;
  ULONG64 Spare;
  PPNP_REPLACE_PROCESSOR_LIST TargetProcessors;
  PPNP_REPLACE_PROCESSOR_LIST SpareProcessors;
  PPNP_REPLACE_MEMORY_LIST TargetMemory;
  PPNP_REPLACE_MEMORY_LIST SpareMemory;
  PREPLACE_MAP_MEMORY MapMemory;
} PNP_REPLACE_PARAMETERS, *PPNP_REPLACE_PARAMETERS;

typedef VOID
(NTAPI *PREPLACE_UNLOAD)(
  VOID);

typedef NTSTATUS
(NTAPI *PREPLACE_BEGIN)(
  IN PPNP_REPLACE_PARAMETERS Parameters,
  OUT PVOID *Context);

typedef NTSTATUS
(NTAPI *PREPLACE_END)(
  IN PVOID Context);

typedef NTSTATUS
(NTAPI *PREPLACE_MIRROR_PHYSICAL_MEMORY)(
  IN PVOID Context,
  IN PHYSICAL_ADDRESS PhysicalAddress,
  IN LARGE_INTEGER ByteCount);

typedef NTSTATUS
(NTAPI *PREPLACE_SET_PROCESSOR_ID)(
  IN PVOID Context,
  IN ULONG ApicId,
  IN BOOLEAN Target);

typedef NTSTATUS
(NTAPI *PREPLACE_SWAP)(
  IN PVOID Context);

typedef NTSTATUS
(NTAPI *PREPLACE_INITIATE_HARDWARE_MIRROR)(
  IN PVOID Context);

typedef NTSTATUS
(NTAPI *PREPLACE_MIRROR_PLATFORM_MEMORY)(
  IN PVOID Context);

typedef NTSTATUS
(NTAPI *PREPLACE_GET_MEMORY_DESTINATION)(
  IN PVOID Context,
  IN PHYSICAL_ADDRESS SourceAddress,
  OUT PPHYSICAL_ADDRESS DestinationAddress);

typedef NTSTATUS
(NTAPI *PREPLACE_ENABLE_DISABLE_HARDWARE_QUIESCE)(
  IN PVOID Context,
  IN BOOLEAN Enable);

#define PNP_REPLACE_DRIVER_INTERFACE_VERSION      1
#define PNP_REPLACE_DRIVER_INTERFACE_MINIMUM_SIZE \
             FIELD_OFFSET(PNP_REPLACE_DRIVER_INTERFACE, InitiateHardwareMirror)

#define PNP_REPLACE_MEMORY_SUPPORTED             0x0001
#define PNP_REPLACE_PROCESSOR_SUPPORTED          0x0002
#define PNP_REPLACE_HARDWARE_MEMORY_MIRRORING    0x0004
#define PNP_REPLACE_HARDWARE_PAGE_COPY           0x0008
#define PNP_REPLACE_HARDWARE_QUIESCE             0x0010

typedef struct _PNP_REPLACE_DRIVER_INTERFACE {
  ULONG Size;
  ULONG Version;
  ULONG Flags;
  PREPLACE_UNLOAD Unload;
  PREPLACE_BEGIN BeginReplace;
  PREPLACE_END EndReplace;
  PREPLACE_MIRROR_PHYSICAL_MEMORY MirrorPhysicalMemory;
  PREPLACE_SET_PROCESSOR_ID SetProcessorId;
  PREPLACE_SWAP Swap;
  PREPLACE_INITIATE_HARDWARE_MIRROR InitiateHardwareMirror;
  PREPLACE_MIRROR_PLATFORM_MEMORY MirrorPlatformMemory;
  PREPLACE_GET_MEMORY_DESTINATION GetMemoryDestination;
  PREPLACE_ENABLE_DISABLE_HARDWARE_QUIESCE EnableDisableHardwareQuiesce;
} PNP_REPLACE_DRIVER_INTERFACE, *PPNP_REPLACE_DRIVER_INTERFACE;

typedef NTSTATUS
(NTAPI *PREPLACE_DRIVER_INIT)(
  IN OUT PPNP_REPLACE_DRIVER_INTERFACE Interface,
  IN PVOID Unused);

typedef enum _DEVICE_USAGE_NOTIFICATION_TYPE {
  DeviceUsageTypeUndefined,
  DeviceUsageTypePaging,
  DeviceUsageTypeHibernation,
  DeviceUsageTypeDumpFile
} DEVICE_USAGE_NOTIFICATION_TYPE;

typedef struct _POWER_SEQUENCE {
  ULONG SequenceD1;
  ULONG SequenceD2;
  ULONG SequenceD3;
} POWER_SEQUENCE, *PPOWER_SEQUENCE;

typedef enum {
  DevicePropertyDeviceDescription = 0x0,
  DevicePropertyHardwareID = 0x1,
  DevicePropertyCompatibleIDs = 0x2,
  DevicePropertyBootConfiguration = 0x3,
  DevicePropertyBootConfigurationTranslated = 0x4,
  DevicePropertyClassName = 0x5,
  DevicePropertyClassGuid = 0x6,
  DevicePropertyDriverKeyName = 0x7,
  DevicePropertyManufacturer = 0x8,
  DevicePropertyFriendlyName = 0x9,
  DevicePropertyLocationInformation = 0xa,
  DevicePropertyPhysicalDeviceObjectName = 0xb,
  DevicePropertyBusTypeGuid = 0xc,
  DevicePropertyLegacyBusType = 0xd,
  DevicePropertyBusNumber = 0xe,
  DevicePropertyEnumeratorName = 0xf,
  DevicePropertyAddress = 0x10,
  DevicePropertyUINumber = 0x11,
  DevicePropertyInstallState = 0x12,
  DevicePropertyRemovalPolicy = 0x13,
  DevicePropertyResourceRequirements = 0x14,
  DevicePropertyAllocatedResources = 0x15,
  DevicePropertyContainerID = 0x16
} DEVICE_REGISTRY_PROPERTY;

typedef enum _IO_NOTIFICATION_EVENT_CATEGORY {
  EventCategoryReserved,
  EventCategoryHardwareProfileChange,
  EventCategoryDeviceInterfaceChange,
  EventCategoryTargetDeviceChange
} IO_NOTIFICATION_EVENT_CATEGORY;

typedef enum _IO_PRIORITY_HINT {
  IoPriorityVeryLow = 0,
  IoPriorityLow,
  IoPriorityNormal,
  IoPriorityHigh,
  IoPriorityCritical,
  MaxIoPriorityTypes
} IO_PRIORITY_HINT;

#define PNPNOTIFY_DEVICE_INTERFACE_INCLUDE_EXISTING_INTERFACES    0x00000001

typedef NTSTATUS
(NTAPI DRIVER_NOTIFICATION_CALLBACK_ROUTINE)(
  IN PVOID NotificationStructure,
  IN PVOID Context);
typedef DRIVER_NOTIFICATION_CALLBACK_ROUTINE *PDRIVER_NOTIFICATION_CALLBACK_ROUTINE;

typedef VOID
(NTAPI DEVICE_CHANGE_COMPLETE_CALLBACK)(
  IN PVOID Context);
typedef DEVICE_CHANGE_COMPLETE_CALLBACK *PDEVICE_CHANGE_COMPLETE_CALLBACK;

typedef enum _FILE_INFORMATION_CLASS {
  FileDirectoryInformation = 1,
  FileFullDirectoryInformation,
  FileBothDirectoryInformation,
  FileBasicInformation,
  FileStandardInformation,
  FileInternalInformation,
  FileEaInformation,
  FileAccessInformation,
  FileNameInformation,
  FileRenameInformation,
  FileLinkInformation,
  FileNamesInformation,
  FileDispositionInformation,
  FilePositionInformation,
  FileFullEaInformation,
  FileModeInformation,
  FileAlignmentInformation,
  FileAllInformation,
  FileAllocationInformation,
  FileEndOfFileInformation,
  FileAlternateNameInformation,
  FileStreamInformation,
  FilePipeInformation,
  FilePipeLocalInformation,
  FilePipeRemoteInformation,
  FileMailslotQueryInformation,
  FileMailslotSetInformation,
  FileCompressionInformation,
  FileObjectIdInformation,
  FileCompletionInformation,
  FileMoveClusterInformation,
  FileQuotaInformation,
  FileReparsePointInformation,
  FileNetworkOpenInformation,
  FileAttributeTagInformation,
  FileTrackingInformation,
  FileIdBothDirectoryInformation,
  FileIdFullDirectoryInformation,
  FileValidDataLengthInformation,
  FileShortNameInformation,
  FileIoCompletionNotificationInformation,
  FileIoStatusBlockRangeInformation,
  FileIoPriorityHintInformation,
  FileSfioReserveInformation,
  FileSfioVolumeInformation,
  FileHardLinkInformation,
  FileProcessIdsUsingFileInformation,
  FileNormalizedNameInformation,
  FileNetworkPhysicalNameInformation,
  FileIdGlobalTxDirectoryInformation,
  FileIsRemoteDeviceInformation,
  FileAttributeCacheInformation,
  FileNumaNodeInformation,
  FileStandardLinkInformation,
  FileRemoteProtocolInformation,
  FileMaximumInformation
} FILE_INFORMATION_CLASS, *PFILE_INFORMATION_CLASS;

typedef struct _FILE_POSITION_INFORMATION {
  LARGE_INTEGER CurrentByteOffset;
} FILE_POSITION_INFORMATION, *PFILE_POSITION_INFORMATION;

typedef struct _FILE_BASIC_INFORMATION {
  LARGE_INTEGER CreationTime;
  LARGE_INTEGER LastAccessTime;
  LARGE_INTEGER LastWriteTime;
  LARGE_INTEGER ChangeTime;
  ULONG FileAttributes;
} FILE_BASIC_INFORMATION, *PFILE_BASIC_INFORMATION;

typedef struct _FILE_IO_PRIORITY_HINT_INFORMATION {
  IO_PRIORITY_HINT PriorityHint;
} FILE_IO_PRIORITY_HINT_INFORMATION, *PFILE_IO_PRIORITY_HINT_INFORMATION;

typedef struct _FILE_IO_COMPLETION_NOTIFICATION_INFORMATION {
  ULONG Flags;
} FILE_IO_COMPLETION_NOTIFICATION_INFORMATION, *PFILE_IO_COMPLETION_NOTIFICATION_INFORMATION;

typedef struct _FILE_IOSTATUSBLOCK_RANGE_INFORMATION {
  PUCHAR IoStatusBlockRange;
  ULONG Length;
} FILE_IOSTATUSBLOCK_RANGE_INFORMATION, *PFILE_IOSTATUSBLOCK_RANGE_INFORMATION;

typedef struct _FILE_IS_REMOTE_DEVICE_INFORMATION {
  BOOLEAN IsRemote;
} FILE_IS_REMOTE_DEVICE_INFORMATION, *PFILE_IS_REMOTE_DEVICE_INFORMATION;

typedef struct _FILE_NUMA_NODE_INFORMATION {
  USHORT NodeNumber;
} FILE_NUMA_NODE_INFORMATION, *PFILE_NUMA_NODE_INFORMATION;

typedef struct _FILE_PROCESS_IDS_USING_FILE_INFORMATION {
  ULONG NumberOfProcessIdsInList;
  ULONG_PTR ProcessIdList[1];
} FILE_PROCESS_IDS_USING_FILE_INFORMATION, *PFILE_PROCESS_IDS_USING_FILE_INFORMATION;

typedef struct _FILE_STANDARD_INFORMATION {
  LARGE_INTEGER AllocationSize;
  LARGE_INTEGER EndOfFile;
  ULONG NumberOfLinks;
  BOOLEAN DeletePending;
  BOOLEAN Directory;
} FILE_STANDARD_INFORMATION, *PFILE_STANDARD_INFORMATION;

typedef struct _FILE_NETWORK_OPEN_INFORMATION {
  LARGE_INTEGER CreationTime;
  LARGE_INTEGER LastAccessTime;
  LARGE_INTEGER LastWriteTime;
  LARGE_INTEGER ChangeTime;
  LARGE_INTEGER AllocationSize;
  LARGE_INTEGER EndOfFile;
  ULONG FileAttributes;
} FILE_NETWORK_OPEN_INFORMATION, *PFILE_NETWORK_OPEN_INFORMATION;

typedef enum _FSINFOCLASS {
  FileFsVolumeInformation = 1,
  FileFsLabelInformation,
  FileFsSizeInformation,
  FileFsDeviceInformation,
  FileFsAttributeInformation,
  FileFsControlInformation,
  FileFsFullSizeInformation,
  FileFsObjectIdInformation,
  FileFsDriverPathInformation,
  FileFsVolumeFlagsInformation,
  FileFsMaximumInformation
} FS_INFORMATION_CLASS, *PFS_INFORMATION_CLASS;

typedef struct _FILE_FS_DEVICE_INFORMATION {
  DEVICE_TYPE DeviceType;
  ULONG Characteristics;
} FILE_FS_DEVICE_INFORMATION, *PFILE_FS_DEVICE_INFORMATION;

typedef struct _FILE_FULL_EA_INFORMATION {
  ULONG NextEntryOffset;
  UCHAR Flags;
  UCHAR EaNameLength;
  USHORT EaValueLength;
  CHAR EaName[1];
} FILE_FULL_EA_INFORMATION, *PFILE_FULL_EA_INFORMATION;

typedef struct _FILE_SFIO_RESERVE_INFORMATION {
  ULONG RequestsPerPeriod;
  ULONG Period;
  BOOLEAN RetryFailures;
  BOOLEAN Discardable;
  ULONG RequestSize;
  ULONG NumOutstandingRequests;
} FILE_SFIO_RESERVE_INFORMATION, *PFILE_SFIO_RESERVE_INFORMATION;

typedef struct _FILE_SFIO_VOLUME_INFORMATION {
  ULONG MaximumRequestsPerPeriod;
  ULONG MinimumPeriod;
  ULONG MinimumTransferSize;
} FILE_SFIO_VOLUME_INFORMATION, *PFILE_SFIO_VOLUME_INFORMATION;

#define FILE_SKIP_COMPLETION_PORT_ON_SUCCESS     0x1
#define FILE_SKIP_SET_EVENT_ON_HANDLE            0x2
#define FILE_SKIP_SET_USER_EVENT_ON_FAST_IO      0x4

#define FM_LOCK_BIT             (0x1)
#define FM_LOCK_BIT_V           (0x0)
#define FM_LOCK_WAITER_WOKEN    (0x2)
#define FM_LOCK_WAITER_INC      (0x4)

typedef BOOLEAN
(NTAPI FAST_IO_CHECK_IF_POSSIBLE)(
  IN struct _FILE_OBJECT *FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN BOOLEAN Wait,
  IN ULONG LockKey,
  IN BOOLEAN CheckForReadOperation,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_CHECK_IF_POSSIBLE *PFAST_IO_CHECK_IF_POSSIBLE;

typedef BOOLEAN
(NTAPI FAST_IO_READ)(
  IN struct _FILE_OBJECT *FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN BOOLEAN Wait,
  IN ULONG LockKey,
  OUT PVOID Buffer,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_READ *PFAST_IO_READ;

typedef BOOLEAN
(NTAPI FAST_IO_WRITE)(
  IN struct _FILE_OBJECT *FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN BOOLEAN Wait,
  IN ULONG LockKey,
  IN PVOID Buffer,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_WRITE *PFAST_IO_WRITE;

typedef BOOLEAN
(NTAPI FAST_IO_QUERY_BASIC_INFO)(
  IN struct _FILE_OBJECT *FileObject,
  IN BOOLEAN Wait,
  OUT PFILE_BASIC_INFORMATION Buffer,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_QUERY_BASIC_INFO *PFAST_IO_QUERY_BASIC_INFO;

typedef BOOLEAN
(NTAPI FAST_IO_QUERY_STANDARD_INFO)(
  IN struct _FILE_OBJECT *FileObject,
  IN BOOLEAN Wait,
  OUT PFILE_STANDARD_INFORMATION Buffer,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_QUERY_STANDARD_INFO *PFAST_IO_QUERY_STANDARD_INFO;

typedef BOOLEAN
(NTAPI FAST_IO_LOCK)(
  IN struct _FILE_OBJECT *FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN PLARGE_INTEGER Length,
  PEPROCESS ProcessId,
  ULONG Key,
  BOOLEAN FailImmediately,
  BOOLEAN ExclusiveLock,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_LOCK *PFAST_IO_LOCK;

typedef BOOLEAN
(NTAPI FAST_IO_UNLOCK_SINGLE)(
  IN struct _FILE_OBJECT *FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN PLARGE_INTEGER Length,
  PEPROCESS ProcessId,
  ULONG Key,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_UNLOCK_SINGLE *PFAST_IO_UNLOCK_SINGLE;

typedef BOOLEAN
(NTAPI FAST_IO_UNLOCK_ALL)(
  IN struct _FILE_OBJECT *FileObject,
  PEPROCESS ProcessId,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_UNLOCK_ALL *PFAST_IO_UNLOCK_ALL;

typedef BOOLEAN
(NTAPI FAST_IO_UNLOCK_ALL_BY_KEY)(
  IN struct _FILE_OBJECT *FileObject,
  PVOID ProcessId,
  ULONG Key,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_UNLOCK_ALL_BY_KEY *PFAST_IO_UNLOCK_ALL_BY_KEY;

typedef BOOLEAN
(NTAPI FAST_IO_DEVICE_CONTROL)(
  IN struct _FILE_OBJECT *FileObject,
  IN BOOLEAN Wait,
  IN PVOID InputBuffer OPTIONAL,
  IN ULONG InputBufferLength,
  OUT PVOID OutputBuffer OPTIONAL,
  IN ULONG OutputBufferLength,
  IN ULONG IoControlCode,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_DEVICE_CONTROL *PFAST_IO_DEVICE_CONTROL;

typedef VOID
(NTAPI FAST_IO_ACQUIRE_FILE)(
  IN struct _FILE_OBJECT *FileObject);
typedef FAST_IO_ACQUIRE_FILE *PFAST_IO_ACQUIRE_FILE;

typedef VOID
(NTAPI FAST_IO_RELEASE_FILE)(
  IN struct _FILE_OBJECT *FileObject);
typedef FAST_IO_RELEASE_FILE *PFAST_IO_RELEASE_FILE;

typedef VOID
(NTAPI FAST_IO_DETACH_DEVICE)(
  IN struct _DEVICE_OBJECT *SourceDevice,
  IN struct _DEVICE_OBJECT *TargetDevice);
typedef FAST_IO_DETACH_DEVICE *PFAST_IO_DETACH_DEVICE;

typedef BOOLEAN
(NTAPI FAST_IO_QUERY_NETWORK_OPEN_INFO)(
  IN struct _FILE_OBJECT *FileObject,
  IN BOOLEAN Wait,
  OUT struct _FILE_NETWORK_OPEN_INFORMATION *Buffer,
  OUT struct _IO_STATUS_BLOCK *IoStatus,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_QUERY_NETWORK_OPEN_INFO *PFAST_IO_QUERY_NETWORK_OPEN_INFO;

typedef NTSTATUS
(NTAPI FAST_IO_ACQUIRE_FOR_MOD_WRITE)(
  IN struct _FILE_OBJECT *FileObject,
  IN PLARGE_INTEGER EndingOffset,
  OUT struct _ERESOURCE **ResourceToRelease,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_ACQUIRE_FOR_MOD_WRITE *PFAST_IO_ACQUIRE_FOR_MOD_WRITE;

typedef BOOLEAN
(NTAPI FAST_IO_MDL_READ)(
  IN struct _FILE_OBJECT *FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN ULONG LockKey,
  OUT PMDL *MdlChain,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_MDL_READ *PFAST_IO_MDL_READ;

typedef BOOLEAN
(NTAPI FAST_IO_MDL_READ_COMPLETE)(
  IN struct _FILE_OBJECT *FileObject,
  IN PMDL MdlChain,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_MDL_READ_COMPLETE *PFAST_IO_MDL_READ_COMPLETE;

typedef BOOLEAN
(NTAPI FAST_IO_PREPARE_MDL_WRITE)(
  IN struct _FILE_OBJECT *FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN ULONG LockKey,
  OUT PMDL *MdlChain,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_PREPARE_MDL_WRITE *PFAST_IO_PREPARE_MDL_WRITE;

typedef BOOLEAN
(NTAPI FAST_IO_MDL_WRITE_COMPLETE)(
  IN struct _FILE_OBJECT *FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN PMDL MdlChain,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_MDL_WRITE_COMPLETE *PFAST_IO_MDL_WRITE_COMPLETE;

typedef BOOLEAN
(NTAPI FAST_IO_READ_COMPRESSED)(
  IN struct _FILE_OBJECT *FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN ULONG LockKey,
  OUT PVOID Buffer,
  OUT PMDL *MdlChain,
  OUT PIO_STATUS_BLOCK IoStatus,
  OUT struct _COMPRESSED_DATA_INFO *CompressedDataInfo,
  IN ULONG CompressedDataInfoLength,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_READ_COMPRESSED *PFAST_IO_READ_COMPRESSED;

typedef BOOLEAN
(NTAPI FAST_IO_WRITE_COMPRESSED)(
  IN struct _FILE_OBJECT *FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN ULONG Length,
  IN ULONG LockKey,
  IN PVOID Buffer,
  OUT PMDL *MdlChain,
  OUT PIO_STATUS_BLOCK IoStatus,
  IN struct _COMPRESSED_DATA_INFO *CompressedDataInfo,
  IN ULONG CompressedDataInfoLength,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_WRITE_COMPRESSED *PFAST_IO_WRITE_COMPRESSED;

typedef BOOLEAN
(NTAPI FAST_IO_MDL_READ_COMPLETE_COMPRESSED)(
  IN struct _FILE_OBJECT *FileObject,
  IN PMDL MdlChain,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_MDL_READ_COMPLETE_COMPRESSED *PFAST_IO_MDL_READ_COMPLETE_COMPRESSED;

typedef BOOLEAN
(NTAPI FAST_IO_MDL_WRITE_COMPLETE_COMPRESSED)(
  IN struct _FILE_OBJECT *FileObject,
  IN PLARGE_INTEGER FileOffset,
  IN PMDL MdlChain,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_MDL_WRITE_COMPLETE_COMPRESSED *PFAST_IO_MDL_WRITE_COMPLETE_COMPRESSED;

typedef BOOLEAN
(NTAPI FAST_IO_QUERY_OPEN)(
  IN struct _IRP *Irp,
  OUT PFILE_NETWORK_OPEN_INFORMATION NetworkInformation,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_QUERY_OPEN *PFAST_IO_QUERY_OPEN;

typedef NTSTATUS
(NTAPI FAST_IO_RELEASE_FOR_MOD_WRITE)(
  IN struct _FILE_OBJECT *FileObject,
  IN struct _ERESOURCE *ResourceToRelease,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_RELEASE_FOR_MOD_WRITE *PFAST_IO_RELEASE_FOR_MOD_WRITE;

typedef NTSTATUS
(NTAPI FAST_IO_ACQUIRE_FOR_CCFLUSH)(
  IN struct _FILE_OBJECT *FileObject,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_ACQUIRE_FOR_CCFLUSH *PFAST_IO_ACQUIRE_FOR_CCFLUSH;

typedef NTSTATUS
(NTAPI FAST_IO_RELEASE_FOR_CCFLUSH)(
  IN struct _FILE_OBJECT *FileObject,
  IN struct _DEVICE_OBJECT *DeviceObject);
typedef FAST_IO_RELEASE_FOR_CCFLUSH *PFAST_IO_RELEASE_FOR_CCFLUSH;

typedef struct _FAST_IO_DISPATCH {
  ULONG SizeOfFastIoDispatch;
  PFAST_IO_CHECK_IF_POSSIBLE FastIoCheckIfPossible;
  PFAST_IO_READ FastIoRead;
  PFAST_IO_WRITE FastIoWrite;
  PFAST_IO_QUERY_BASIC_INFO FastIoQueryBasicInfo;
  PFAST_IO_QUERY_STANDARD_INFO FastIoQueryStandardInfo;
  PFAST_IO_LOCK FastIoLock;
  PFAST_IO_UNLOCK_SINGLE FastIoUnlockSingle;
  PFAST_IO_UNLOCK_ALL FastIoUnlockAll;
  PFAST_IO_UNLOCK_ALL_BY_KEY FastIoUnlockAllByKey;
  PFAST_IO_DEVICE_CONTROL FastIoDeviceControl;
  PFAST_IO_ACQUIRE_FILE AcquireFileForNtCreateSection;
  PFAST_IO_RELEASE_FILE ReleaseFileForNtCreateSection;
  PFAST_IO_DETACH_DEVICE FastIoDetachDevice;
  PFAST_IO_QUERY_NETWORK_OPEN_INFO FastIoQueryNetworkOpenInfo;
  PFAST_IO_ACQUIRE_FOR_MOD_WRITE AcquireForModWrite;
  PFAST_IO_MDL_READ MdlRead;
  PFAST_IO_MDL_READ_COMPLETE MdlReadComplete;
  PFAST_IO_PREPARE_MDL_WRITE PrepareMdlWrite;
  PFAST_IO_MDL_WRITE_COMPLETE MdlWriteComplete;
  PFAST_IO_READ_COMPRESSED FastIoReadCompressed;
  PFAST_IO_WRITE_COMPRESSED FastIoWriteCompressed;
  PFAST_IO_MDL_READ_COMPLETE_COMPRESSED MdlReadCompleteCompressed;
  PFAST_IO_MDL_WRITE_COMPLETE_COMPRESSED MdlWriteCompleteCompressed;
  PFAST_IO_QUERY_OPEN FastIoQueryOpen;
  PFAST_IO_RELEASE_FOR_MOD_WRITE ReleaseForModWrite;
  PFAST_IO_ACQUIRE_FOR_CCFLUSH AcquireForCcFlush;
  PFAST_IO_RELEASE_FOR_CCFLUSH ReleaseForCcFlush;
} FAST_IO_DISPATCH, *PFAST_IO_DISPATCH;

typedef struct _SECTION_OBJECT_POINTERS {
  PVOID DataSectionObject;
  PVOID SharedCacheMap;
  PVOID ImageSectionObject;
} SECTION_OBJECT_POINTERS, *PSECTION_OBJECT_POINTERS;

typedef struct _IO_COMPLETION_CONTEXT {
  PVOID Port;
  PVOID Key;
} IO_COMPLETION_CONTEXT, *PIO_COMPLETION_CONTEXT;

/* FILE_OBJECT.Flags */
#define FO_FILE_OPEN                 0x00000001
#define FO_SYNCHRONOUS_IO            0x00000002
#define FO_ALERTABLE_IO              0x00000004
#define FO_NO_INTERMEDIATE_BUFFERING 0x00000008
#define FO_WRITE_THROUGH             0x00000010
#define FO_SEQUENTIAL_ONLY           0x00000020
#define FO_CACHE_SUPPORTED           0x00000040
#define FO_NAMED_PIPE                0x00000080
#define FO_STREAM_FILE               0x00000100
#define FO_MAILSLOT                  0x00000200
#define FO_GENERATE_AUDIT_ON_CLOSE   0x00000400
#define FO_QUEUE_IRP_TO_THREAD       0x00000400
#define FO_DIRECT_DEVICE_OPEN        0x00000800
#define FO_FILE_MODIFIED             0x00001000
#define FO_FILE_SIZE_CHANGED         0x00002000
#define FO_CLEANUP_COMPLETE          0x00004000
#define FO_TEMPORARY_FILE            0x00008000
#define FO_DELETE_ON_CLOSE           0x00010000
#define FO_OPENED_CASE_SENSITIVE     0x00020000
#define FO_HANDLE_CREATED            0x00040000
#define FO_FILE_FAST_IO_READ         0x00080000
#define FO_RANDOM_ACCESS             0x00100000
#define FO_FILE_OPEN_CANCELLED       0x00200000
#define FO_VOLUME_OPEN               0x00400000
#define FO_REMOTE_ORIGIN             0x01000000
#define FO_DISALLOW_EXCLUSIVE        0x02000000
#define FO_SKIP_COMPLETION_PORT      0x02000000
#define FO_SKIP_SET_EVENT            0x04000000
#define FO_SKIP_SET_FAST_IO          0x08000000
#define FO_FLAGS_VALID_ONLY_DURING_CREATE FO_DISALLOW_EXCLUSIVE

/* VPB.Flags */
#define VPB_MOUNTED                       0x0001
#define VPB_LOCKED                        0x0002
#define VPB_PERSISTENT                    0x0004
#define VPB_REMOVE_PENDING                0x0008
#define VPB_RAW_MOUNT                     0x0010
#define VPB_DIRECT_WRITES_ALLOWED         0x0020

/* IRP.Flags */

#define SL_FORCE_ACCESS_CHECK             0x01
#define SL_OPEN_PAGING_FILE               0x02
#define SL_OPEN_TARGET_DIRECTORY          0x04
#define SL_STOP_ON_SYMLINK                0x08
#define SL_CASE_SENSITIVE                 0x80

#define SL_KEY_SPECIFIED                  0x01
#define SL_OVERRIDE_VERIFY_VOLUME         0x02
#define SL_WRITE_THROUGH                  0x04
#define SL_FT_SEQUENTIAL_WRITE            0x08
#define SL_FORCE_DIRECT_WRITE             0x10
#define SL_REALTIME_STREAM                0x20

#define SL_READ_ACCESS_GRANTED            0x01
#define SL_WRITE_ACCESS_GRANTED           0x04

#define SL_FAIL_IMMEDIATELY               0x01
#define SL_EXCLUSIVE_LOCK                 0x02

#define SL_RESTART_SCAN                   0x01
#define SL_RETURN_SINGLE_ENTRY            0x02
#define SL_INDEX_SPECIFIED                0x04

#define SL_WATCH_TREE                     0x01

#define SL_ALLOW_RAW_MOUNT                0x01

#define CTL_CODE(DeviceType, Function, Method, Access) \
  (((DeviceType) << 16) | ((Access) << 14) | ((Function) << 2) | (Method))

#define DEVICE_TYPE_FROM_CTL_CODE(ctl) (((ULONG) (ctl & 0xffff0000)) >> 16)

#define METHOD_FROM_CTL_CODE(ctrlCode)          ((ULONG)(ctrlCode & 3))

#define IRP_NOCACHE                     0x00000001
#define IRP_PAGING_IO                   0x00000002
#define IRP_MOUNT_COMPLETION            0x00000002
#define IRP_SYNCHRONOUS_API             0x00000004
#define IRP_ASSOCIATED_IRP              0x00000008
#define IRP_BUFFERED_IO                 0x00000010
#define IRP_DEALLOCATE_BUFFER           0x00000020
#define IRP_INPUT_OPERATION             0x00000040
#define IRP_SYNCHRONOUS_PAGING_IO       0x00000040
#define IRP_CREATE_OPERATION            0x00000080
#define IRP_READ_OPERATION              0x00000100
#define IRP_WRITE_OPERATION             0x00000200
#define IRP_CLOSE_OPERATION             0x00000400
#define IRP_DEFER_IO_COMPLETION         0x00000800
#define IRP_OB_QUERY_NAME               0x00001000
#define IRP_HOLD_DEVICE_QUEUE           0x00002000
#define IRP_RETRY_IO_COMPLETION         0x00004000
#define IRP_CLASS_CACHE_OPERATION       0x00008000

#define IRP_QUOTA_CHARGED                 0x01
#define IRP_ALLOCATED_MUST_SUCCEED        0x02
#define IRP_ALLOCATED_FIXED_SIZE          0x04
#define IRP_LOOKASIDE_ALLOCATION          0x08

/*
** IRP function codes
*/

#define IRP_MJ_CREATE                     0x00
#define IRP_MJ_CREATE_NAMED_PIPE          0x01
#define IRP_MJ_CLOSE                      0x02
#define IRP_MJ_READ                       0x03
#define IRP_MJ_WRITE                      0x04
#define IRP_MJ_QUERY_INFORMATION          0x05
#define IRP_MJ_SET_INFORMATION            0x06
#define IRP_MJ_QUERY_EA                   0x07
#define IRP_MJ_SET_EA                     0x08
#define IRP_MJ_FLUSH_BUFFERS              0x09
#define IRP_MJ_QUERY_VOLUME_INFORMATION   0x0a
#define IRP_MJ_SET_VOLUME_INFORMATION     0x0b
#define IRP_MJ_DIRECTORY_CONTROL          0x0c
#define IRP_MJ_FILE_SYSTEM_CONTROL        0x0d
#define IRP_MJ_DEVICE_CONTROL             0x0e
#define IRP_MJ_INTERNAL_DEVICE_CONTROL    0x0f
#define IRP_MJ_SCSI                       0x0f
#define IRP_MJ_SHUTDOWN                   0x10
#define IRP_MJ_LOCK_CONTROL               0x11
#define IRP_MJ_CLEANUP                    0x12
#define IRP_MJ_CREATE_MAILSLOT            0x13
#define IRP_MJ_QUERY_SECURITY             0x14
#define IRP_MJ_SET_SECURITY               0x15
#define IRP_MJ_POWER                      0x16
#define IRP_MJ_SYSTEM_CONTROL             0x17
#define IRP_MJ_DEVICE_CHANGE              0x18
#define IRP_MJ_QUERY_QUOTA                0x19
#define IRP_MJ_SET_QUOTA                  0x1a
#define IRP_MJ_PNP                        0x1b
#define IRP_MJ_PNP_POWER                  0x1b
#define IRP_MJ_MAXIMUM_FUNCTION           0x1b

#define IRP_MN_SCSI_CLASS                 0x01

#define IRP_MN_START_DEVICE               0x00
#define IRP_MN_QUERY_REMOVE_DEVICE        0x01
#define IRP_MN_REMOVE_DEVICE              0x02
#define IRP_MN_CANCEL_REMOVE_DEVICE       0x03
#define IRP_MN_STOP_DEVICE                0x04
#define IRP_MN_QUERY_STOP_DEVICE          0x05
#define IRP_MN_CANCEL_STOP_DEVICE         0x06

#define IRP_MN_QUERY_DEVICE_RELATIONS       0x07
#define IRP_MN_QUERY_INTERFACE              0x08
#define IRP_MN_QUERY_CAPABILITIES           0x09
#define IRP_MN_QUERY_RESOURCES              0x0A
#define IRP_MN_QUERY_RESOURCE_REQUIREMENTS  0x0B
#define IRP_MN_QUERY_DEVICE_TEXT            0x0C
#define IRP_MN_FILTER_RESOURCE_REQUIREMENTS 0x0D

#define IRP_MN_READ_CONFIG                  0x0F
#define IRP_MN_WRITE_CONFIG                 0x10
#define IRP_MN_EJECT                        0x11
#define IRP_MN_SET_LOCK                     0x12
#define IRP_MN_QUERY_ID                     0x13
#define IRP_MN_QUERY_PNP_DEVICE_STATE       0x14
#define IRP_MN_QUERY_BUS_INFORMATION        0x15
#define IRP_MN_DEVICE_USAGE_NOTIFICATION    0x16
#define IRP_MN_SURPRISE_REMOVAL             0x17
#if (NTDDI_VERSION >= NTDDI_WIN7)
#define IRP_MN_DEVICE_ENUMERATED            0x19
#endif

#define IRP_MN_WAIT_WAKE                  0x00
#define IRP_MN_POWER_SEQUENCE             0x01
#define IRP_MN_SET_POWER                  0x02
#define IRP_MN_QUERY_POWER                0x03

#define IRP_MN_QUERY_ALL_DATA             0x00
#define IRP_MN_QUERY_SINGLE_INSTANCE      0x01
#define IRP_MN_CHANGE_SINGLE_INSTANCE     0x02
#define IRP_MN_CHANGE_SINGLE_ITEM         0x03
#define IRP_MN_ENABLE_EVENTS              0x04
#define IRP_MN_DISABLE_EVENTS             0x05
#define IRP_MN_ENABLE_COLLECTION          0x06
#define IRP_MN_DISABLE_COLLECTION         0x07
#define IRP_MN_REGINFO                    0x08
#define IRP_MN_EXECUTE_METHOD             0x09

#define IRP_MN_REGINFO_EX                 0x0b

typedef struct _FILE_OBJECT {
  CSHORT Type;
  CSHORT Size;
  PDEVICE_OBJECT DeviceObject;
  PVPB Vpb;
  PVOID FsContext;
  PVOID FsContext2;
  PSECTION_OBJECT_POINTERS SectionObjectPointer;
  PVOID PrivateCacheMap;
  NTSTATUS FinalStatus;
  struct _FILE_OBJECT *RelatedFileObject;
  BOOLEAN LockOperation;
  BOOLEAN DeletePending;
  BOOLEAN ReadAccess;
  BOOLEAN WriteAccess;
  BOOLEAN DeleteAccess;
  BOOLEAN SharedRead;
  BOOLEAN SharedWrite;
  BOOLEAN SharedDelete;
  ULONG Flags;
  UNICODE_STRING FileName;
  LARGE_INTEGER CurrentByteOffset;
  volatile ULONG Waiters;
  volatile ULONG Busy;
  PVOID LastLock;
  KEVENT Lock;
  KEVENT Event;
  volatile PIO_COMPLETION_CONTEXT CompletionContext;
  KSPIN_LOCK IrpListLock;
  LIST_ENTRY IrpList;
  volatile PVOID FileObjectExtension;
} FILE_OBJECT, *PFILE_OBJECT;

typedef struct _IO_ERROR_LOG_PACKET {
  UCHAR MajorFunctionCode;
  UCHAR RetryCount;
  USHORT DumpDataSize;
  USHORT NumberOfStrings;
  USHORT StringOffset;
  USHORT EventCategory;
  NTSTATUS ErrorCode;
  ULONG UniqueErrorValue;
  NTSTATUS FinalStatus;
  ULONG SequenceNumber;
  ULONG IoControlCode;
  LARGE_INTEGER DeviceOffset;
  ULONG DumpData[1];
} IO_ERROR_LOG_PACKET, *PIO_ERROR_LOG_PACKET;

typedef struct _IO_ERROR_LOG_MESSAGE {
  USHORT Type;
  USHORT Size;
  USHORT DriverNameLength;
  LARGE_INTEGER TimeStamp;
  ULONG DriverNameOffset;
  IO_ERROR_LOG_PACKET EntryData;
} IO_ERROR_LOG_MESSAGE, *PIO_ERROR_LOG_MESSAGE;

#define ERROR_LOG_LIMIT_SIZE               240

#define IO_ERROR_LOG_MESSAGE_HEADER_LENGTH (sizeof(IO_ERROR_LOG_MESSAGE) - \
                                            sizeof(IO_ERROR_LOG_PACKET) +  \
                                            (sizeof(WCHAR) * 40))

#define ERROR_LOG_MESSAGE_LIMIT_SIZE                                       \
    (ERROR_LOG_LIMIT_SIZE + IO_ERROR_LOG_MESSAGE_HEADER_LENGTH)

#define IO_ERROR_LOG_MESSAGE_LENGTH                                        \
    ((PORT_MAXIMUM_MESSAGE_LENGTH > ERROR_LOG_MESSAGE_LIMIT_SIZE) ?        \
        ERROR_LOG_MESSAGE_LIMIT_SIZE :                                     \
        PORT_MAXIMUM_MESSAGE_LENGTH)

#define ERROR_LOG_MAXIMUM_SIZE (IO_ERROR_LOG_MESSAGE_LENGTH -              \
                                IO_ERROR_LOG_MESSAGE_HEADER_LENGTH)

#ifdef _WIN64
#define PORT_MAXIMUM_MESSAGE_LENGTH    512
#else
#define PORT_MAXIMUM_MESSAGE_LENGTH    256
#endif

typedef enum _DMA_WIDTH {
  Width8Bits,
  Width16Bits,
  Width32Bits,
  MaximumDmaWidth
} DMA_WIDTH, *PDMA_WIDTH;

typedef enum _DMA_SPEED {
  Compatible,
  TypeA,
  TypeB,
  TypeC,
  TypeF,
  MaximumDmaSpeed
} DMA_SPEED, *PDMA_SPEED;

/* DEVICE_DESCRIPTION.Version */

#define DEVICE_DESCRIPTION_VERSION        0x0000
#define DEVICE_DESCRIPTION_VERSION1       0x0001
#define DEVICE_DESCRIPTION_VERSION2       0x0002

typedef struct _DEVICE_DESCRIPTION {
  ULONG Version;
  BOOLEAN Master;
  BOOLEAN ScatterGather;
  BOOLEAN DemandMode;
  BOOLEAN AutoInitialize;
  BOOLEAN Dma32BitAddresses;
  BOOLEAN IgnoreCount;
  BOOLEAN Reserved1;
  BOOLEAN Dma64BitAddresses;
  ULONG BusNumber;
  ULONG DmaChannel;
  INTERFACE_TYPE InterfaceType;
  DMA_WIDTH DmaWidth;
  DMA_SPEED DmaSpeed;
  ULONG MaximumLength;
  ULONG DmaPort;
} DEVICE_DESCRIPTION, *PDEVICE_DESCRIPTION;

typedef enum _DEVICE_RELATION_TYPE {
  BusRelations,
  EjectionRelations,
  PowerRelations,
  RemovalRelations,
  TargetDeviceRelation,
  SingleBusRelations,
  TransportRelations
} DEVICE_RELATION_TYPE, *PDEVICE_RELATION_TYPE;

typedef struct _DEVICE_RELATIONS {
  ULONG Count;
  PDEVICE_OBJECT Objects[1];
} DEVICE_RELATIONS, *PDEVICE_RELATIONS;

typedef struct _DEVOBJ_EXTENSION {
  CSHORT Type;
  USHORT Size;
  PDEVICE_OBJECT DeviceObject;
} DEVOBJ_EXTENSION, *PDEVOBJ_EXTENSION;

typedef struct _SCATTER_GATHER_ELEMENT {
  PHYSICAL_ADDRESS Address;
  ULONG Length;
  ULONG_PTR Reserved;
} SCATTER_GATHER_ELEMENT, *PSCATTER_GATHER_ELEMENT;

#if defined(_MSC_EXTENSIONS) || defined(__GNUC__)

#if defined(_MSC_VER)
#if _MSC_VER >= 1200
#pragma warning(push)
#endif
#pragma warning(disable:4200)
#endif /* _MSC_VER */

typedef struct _SCATTER_GATHER_LIST {
  ULONG NumberOfElements;
  ULONG_PTR Reserved;
  SCATTER_GATHER_ELEMENT Elements[1];
} SCATTER_GATHER_LIST, *PSCATTER_GATHER_LIST;

#if defined(_MSC_VER)
#if _MSC_VER >= 1200
#pragma warning(pop)
#else
#pragma warning(default:4200)
#endif
#endif /* _MSC_VER */

#else /* defined(_MSC_EXTENSIONS) || defined(__GNUC__) */

struct _SCATTER_GATHER_LIST;
typedef struct _SCATTER_GATHER_LIST SCATTER_GATHER_LIST, *PSCATTER_GATHER_LIST;

#endif /* defined(_MSC_EXTENSIONS) || defined(__GNUC__) */

typedef NTSTATUS
(NTAPI DRIVER_ADD_DEVICE)(
  IN struct _DRIVER_OBJECT *DriverObject,
  IN struct _DEVICE_OBJECT *PhysicalDeviceObject);
typedef DRIVER_ADD_DEVICE *PDRIVER_ADD_DEVICE;

typedef struct _DRIVER_EXTENSION {
  struct _DRIVER_OBJECT *DriverObject;
  PDRIVER_ADD_DEVICE AddDevice;
  ULONG Count;
  UNICODE_STRING ServiceKeyName;
} DRIVER_EXTENSION, *PDRIVER_EXTENSION;

#define DRVO_UNLOAD_INVOKED               0x00000001
#define DRVO_LEGACY_DRIVER                0x00000002
#define DRVO_BUILTIN_DRIVER               0x00000004

typedef NTSTATUS
(NTAPI DRIVER_INITIALIZE)(
  IN struct _DRIVER_OBJECT *DriverObject,
  IN PUNICODE_STRING RegistryPath);
typedef DRIVER_INITIALIZE *PDRIVER_INITIALIZE;

typedef VOID
(NTAPI DRIVER_STARTIO)(
  IN struct _DEVICE_OBJECT *DeviceObject,
  IN struct _IRP *Irp);
typedef DRIVER_STARTIO *PDRIVER_STARTIO;

typedef VOID
(NTAPI DRIVER_UNLOAD)(
  IN struct _DRIVER_OBJECT *DriverObject);
typedef DRIVER_UNLOAD *PDRIVER_UNLOAD;

typedef NTSTATUS
(NTAPI DRIVER_DISPATCH)(
  IN struct _DEVICE_OBJECT *DeviceObject,
  IN struct _IRP *Irp);
typedef DRIVER_DISPATCH *PDRIVER_DISPATCH;

typedef struct _DRIVER_OBJECT {
  CSHORT Type;
  CSHORT Size;
  PDEVICE_OBJECT DeviceObject;
  ULONG Flags;
  PVOID DriverStart;
  ULONG DriverSize;
  PVOID DriverSection;
  PDRIVER_EXTENSION DriverExtension;
  UNICODE_STRING DriverName;
  PUNICODE_STRING HardwareDatabase;
  struct _FAST_IO_DISPATCH *FastIoDispatch;
  PDRIVER_INITIALIZE DriverInit;
  PDRIVER_STARTIO DriverStartIo;
  PDRIVER_UNLOAD DriverUnload;
  PDRIVER_DISPATCH MajorFunction[IRP_MJ_MAXIMUM_FUNCTION + 1];
} DRIVER_OBJECT, *PDRIVER_OBJECT;

typedef struct _DMA_ADAPTER {
  USHORT Version;
  USHORT Size;
  struct _DMA_OPERATIONS* DmaOperations;
} DMA_ADAPTER, *PDMA_ADAPTER;

typedef VOID
(NTAPI *PPUT_DMA_ADAPTER)(
  IN PDMA_ADAPTER DmaAdapter);

typedef PVOID
(NTAPI *PALLOCATE_COMMON_BUFFER)(
  IN PDMA_ADAPTER DmaAdapter,
  IN ULONG Length,
  OUT PPHYSICAL_ADDRESS LogicalAddress,
  IN BOOLEAN CacheEnabled);

typedef VOID
(NTAPI *PFREE_COMMON_BUFFER)(
  IN PDMA_ADAPTER DmaAdapter,
  IN ULONG Length,
  IN PHYSICAL_ADDRESS LogicalAddress,
  IN PVOID VirtualAddress,
  IN BOOLEAN CacheEnabled);

typedef NTSTATUS
(NTAPI *PALLOCATE_ADAPTER_CHANNEL)(
  IN PDMA_ADAPTER DmaAdapter,
  IN PDEVICE_OBJECT DeviceObject,
  IN ULONG NumberOfMapRegisters,
  IN PDRIVER_CONTROL ExecutionRoutine,
  IN PVOID Context);

typedef BOOLEAN
(NTAPI *PFLUSH_ADAPTER_BUFFERS)(
  IN PDMA_ADAPTER DmaAdapter,
  IN PMDL Mdl,
  IN PVOID MapRegisterBase,
  IN PVOID CurrentVa,
  IN ULONG Length,
  IN BOOLEAN WriteToDevice);

typedef VOID
(NTAPI *PFREE_ADAPTER_CHANNEL)(
  IN PDMA_ADAPTER DmaAdapter);

typedef VOID
(NTAPI *PFREE_MAP_REGISTERS)(
  IN PDMA_ADAPTER DmaAdapter,
  PVOID MapRegisterBase,
  ULONG NumberOfMapRegisters);

typedef PHYSICAL_ADDRESS
(NTAPI *PMAP_TRANSFER)(
  IN PDMA_ADAPTER DmaAdapter,
  IN PMDL Mdl,
  IN PVOID MapRegisterBase,
  IN PVOID CurrentVa,
  IN OUT PULONG Length,
  IN BOOLEAN WriteToDevice);

typedef ULONG
(NTAPI *PGET_DMA_ALIGNMENT)(
  IN PDMA_ADAPTER DmaAdapter);

typedef ULONG
(NTAPI *PREAD_DMA_COUNTER)(
  IN PDMA_ADAPTER DmaAdapter);

typedef VOID
(NTAPI DRIVER_LIST_CONTROL)(
  IN struct _DEVICE_OBJECT *DeviceObject,
  IN struct _IRP *Irp,
  IN struct _SCATTER_GATHER_LIST *ScatterGather,
  IN PVOID Context);
typedef DRIVER_LIST_CONTROL *PDRIVER_LIST_CONTROL;

typedef NTSTATUS
(NTAPI *PGET_SCATTER_GATHER_LIST)(
  IN PDMA_ADAPTER DmaAdapter,
  IN PDEVICE_OBJECT DeviceObject,
  IN PMDL Mdl,
  IN PVOID CurrentVa,
  IN ULONG Length,
  IN PDRIVER_LIST_CONTROL ExecutionRoutine,
  IN PVOID Context,
  IN BOOLEAN WriteToDevice);

typedef VOID
(NTAPI *PPUT_SCATTER_GATHER_LIST)(
  IN PDMA_ADAPTER DmaAdapter,
  IN PSCATTER_GATHER_LIST ScatterGather,
  IN BOOLEAN WriteToDevice);

typedef NTSTATUS
(NTAPI *PCALCULATE_SCATTER_GATHER_LIST_SIZE)(
  IN PDMA_ADAPTER DmaAdapter,
  IN PMDL Mdl OPTIONAL,
  IN PVOID CurrentVa,
  IN ULONG Length,
  OUT PULONG ScatterGatherListSize,
  OUT PULONG pNumberOfMapRegisters OPTIONAL);

typedef NTSTATUS
(NTAPI *PBUILD_SCATTER_GATHER_LIST)(
  IN PDMA_ADAPTER DmaAdapter,
  IN PDEVICE_OBJECT DeviceObject,
  IN PMDL Mdl,
  IN PVOID CurrentVa,
  IN ULONG Length,
  IN PDRIVER_LIST_CONTROL ExecutionRoutine,
  IN PVOID Context,
  IN BOOLEAN WriteToDevice,
  IN PVOID ScatterGatherBuffer,
  IN ULONG ScatterGatherLength);

typedef NTSTATUS
(NTAPI *PBUILD_MDL_FROM_SCATTER_GATHER_LIST)(
  IN PDMA_ADAPTER DmaAdapter,
  IN PSCATTER_GATHER_LIST ScatterGather,
  IN PMDL OriginalMdl,
  OUT PMDL *TargetMdl);

typedef struct _DMA_OPERATIONS {
  ULONG Size;
  PPUT_DMA_ADAPTER PutDmaAdapter;
  PALLOCATE_COMMON_BUFFER AllocateCommonBuffer;
  PFREE_COMMON_BUFFER FreeCommonBuffer;
  PALLOCATE_ADAPTER_CHANNEL AllocateAdapterChannel;
  PFLUSH_ADAPTER_BUFFERS FlushAdapterBuffers;
  PFREE_ADAPTER_CHANNEL FreeAdapterChannel;
  PFREE_MAP_REGISTERS FreeMapRegisters;
  PMAP_TRANSFER MapTransfer;
  PGET_DMA_ALIGNMENT GetDmaAlignment;
  PREAD_DMA_COUNTER ReadDmaCounter;
  PGET_SCATTER_GATHER_LIST GetScatterGatherList;
  PPUT_SCATTER_GATHER_LIST PutScatterGatherList;
  PCALCULATE_SCATTER_GATHER_LIST_SIZE CalculateScatterGatherList;
  PBUILD_SCATTER_GATHER_LIST BuildScatterGatherList;
  PBUILD_MDL_FROM_SCATTER_GATHER_LIST BuildMdlFromScatterGatherList;
} DMA_OPERATIONS, *PDMA_OPERATIONS;

typedef struct _IO_RESOURCE_DESCRIPTOR {
  UCHAR Option;
  UCHAR Type;
  UCHAR ShareDisposition;
  UCHAR Spare1;
  USHORT Flags;
  USHORT Spare2;
  union {
    struct {
      ULONG Length;
      ULONG Alignment;
      PHYSICAL_ADDRESS MinimumAddress;
      PHYSICAL_ADDRESS MaximumAddress;
    } Port;
    struct {
      ULONG Length;
      ULONG Alignment;
      PHYSICAL_ADDRESS MinimumAddress;
      PHYSICAL_ADDRESS MaximumAddress;
    } Memory;
    struct {
      ULONG MinimumVector;
      ULONG MaximumVector;
    } Interrupt;
    struct {
      ULONG MinimumChannel;
      ULONG MaximumChannel;
    } Dma;
    struct {
      ULONG Length;
      ULONG Alignment;
      PHYSICAL_ADDRESS MinimumAddress;
      PHYSICAL_ADDRESS MaximumAddress;
    } Generic;
    struct {
      ULONG Data[3];
    } DevicePrivate;
    struct {
      ULONG Length;
      ULONG MinBusNumber;
      ULONG MaxBusNumber;
      ULONG Reserved;
    } BusNumber;
    struct {
      ULONG Priority;
      ULONG Reserved1;
      ULONG Reserved2;
    } ConfigData;
  } u;
} IO_RESOURCE_DESCRIPTOR, *PIO_RESOURCE_DESCRIPTOR;

typedef struct _IO_RESOURCE_LIST {
  USHORT Version;
  USHORT Revision;
  ULONG Count;
  IO_RESOURCE_DESCRIPTOR Descriptors[1];
} IO_RESOURCE_LIST, *PIO_RESOURCE_LIST;

typedef struct _IO_RESOURCE_REQUIREMENTS_LIST {
  ULONG ListSize;
  INTERFACE_TYPE InterfaceType;
  ULONG BusNumber;
  ULONG SlotNumber;
  ULONG Reserved[3];
  ULONG AlternativeLists;
  IO_RESOURCE_LIST List[1];
} IO_RESOURCE_REQUIREMENTS_LIST, *PIO_RESOURCE_REQUIREMENTS_LIST;

typedef VOID
(NTAPI DRIVER_CANCEL)(
  IN struct _DEVICE_OBJECT *DeviceObject,
  IN struct _IRP *Irp);
typedef DRIVER_CANCEL *PDRIVER_CANCEL;

typedef struct _IRP {
  CSHORT Type;
  USHORT Size;
  struct _MDL *MdlAddress;
  ULONG Flags;
  union {
    struct _IRP *MasterIrp;
    volatile LONG IrpCount;
    PVOID SystemBuffer;
  } AssociatedIrp;
  LIST_ENTRY ThreadListEntry;
  IO_STATUS_BLOCK IoStatus;
  KPROCESSOR_MODE RequestorMode;
  BOOLEAN PendingReturned;
  CHAR StackCount;
  CHAR CurrentLocation;
  BOOLEAN Cancel;
  KIRQL CancelIrql;
  CCHAR ApcEnvironment;
  UCHAR AllocationFlags;
  PIO_STATUS_BLOCK UserIosb;
  PKEVENT UserEvent;
  union {
    struct {
      _ANONYMOUS_UNION union {
        PIO_APC_ROUTINE UserApcRoutine;
        PVOID IssuingProcess;
      } DUMMYUNIONNAME;
      PVOID UserApcContext;
    } AsynchronousParameters;
    LARGE_INTEGER AllocationSize;
  } Overlay;
  volatile PDRIVER_CANCEL CancelRoutine;
  PVOID UserBuffer;
  union {
    struct {
      _ANONYMOUS_UNION union {
        KDEVICE_QUEUE_ENTRY DeviceQueueEntry;
        _ANONYMOUS_STRUCT struct {
          PVOID DriverContext[4];
        } DUMMYSTRUCTNAME;
      } DUMMYUNIONNAME;
      PETHREAD Thread;
      PCHAR AuxiliaryBuffer;
      _ANONYMOUS_STRUCT struct {
        LIST_ENTRY ListEntry;
        _ANONYMOUS_UNION union {
          struct _IO_STACK_LOCATION *CurrentStackLocation;
          ULONG PacketType;
        } DUMMYUNIONNAME;
      } DUMMYSTRUCTNAME;
      struct _FILE_OBJECT *OriginalFileObject;
    } Overlay;
    KAPC Apc;
    PVOID CompletionKey;
  } Tail;
} IRP, *PIRP;

typedef enum _IO_PAGING_PRIORITY {
  IoPagingPriorityInvalid,
  IoPagingPriorityNormal,
  IoPagingPriorityHigh,
  IoPagingPriorityReserved1,
  IoPagingPriorityReserved2
} IO_PAGING_PRIORITY;

typedef NTSTATUS
(NTAPI IO_COMPLETION_ROUTINE)(
  IN struct _DEVICE_OBJECT *DeviceObject,
  IN struct _IRP *Irp,
  IN PVOID Context);
typedef IO_COMPLETION_ROUTINE *PIO_COMPLETION_ROUTINE;

typedef VOID
(NTAPI IO_DPC_ROUTINE)(
  IN struct _KDPC *Dpc,
  IN struct _DEVICE_OBJECT *DeviceObject,
  IN struct _IRP *Irp,
  IN PVOID Context);
typedef IO_DPC_ROUTINE *PIO_DPC_ROUTINE;

typedef NTSTATUS
(NTAPI *PMM_DLL_INITIALIZE)(
  IN PUNICODE_STRING RegistryPath);

typedef NTSTATUS
(NTAPI *PMM_DLL_UNLOAD)(
  VOID);

typedef VOID
(NTAPI IO_TIMER_ROUTINE)(
  IN struct _DEVICE_OBJECT *DeviceObject,
  IN PVOID Context);
typedef IO_TIMER_ROUTINE *PIO_TIMER_ROUTINE;

typedef struct _IO_SECURITY_CONTEXT {
  PSECURITY_QUALITY_OF_SERVICE SecurityQos;
  PACCESS_STATE AccessState;
  ACCESS_MASK DesiredAccess;
  ULONG FullCreateOptions;
} IO_SECURITY_CONTEXT, *PIO_SECURITY_CONTEXT;

struct _IO_CSQ;

typedef struct _IO_CSQ_IRP_CONTEXT {
  ULONG Type;
  struct _IRP *Irp;
  struct _IO_CSQ *Csq;
} IO_CSQ_IRP_CONTEXT, *PIO_CSQ_IRP_CONTEXT;

typedef VOID
(NTAPI *PIO_CSQ_INSERT_IRP)(
  IN struct _IO_CSQ *Csq,
  IN PIRP Irp);

typedef NTSTATUS
(NTAPI IO_CSQ_INSERT_IRP_EX)(
  IN struct _IO_CSQ *Csq,
  IN PIRP Irp,
  IN PVOID InsertContext);
typedef IO_CSQ_INSERT_IRP_EX *PIO_CSQ_INSERT_IRP_EX;

typedef VOID
(NTAPI *PIO_CSQ_REMOVE_IRP)(
  IN struct _IO_CSQ *Csq,
  IN PIRP Irp);

typedef PIRP
(NTAPI *PIO_CSQ_PEEK_NEXT_IRP)(
  IN struct _IO_CSQ *Csq,
  IN PIRP Irp,
  IN PVOID PeekContext);

typedef VOID
(NTAPI *PIO_CSQ_ACQUIRE_LOCK)(
  IN struct _IO_CSQ *Csq,
  OUT PKIRQL Irql);

typedef VOID
(NTAPI *PIO_CSQ_RELEASE_LOCK)(
  IN struct _IO_CSQ *Csq,
  IN KIRQL Irql);

typedef VOID
(NTAPI *PIO_CSQ_COMPLETE_CANCELED_IRP)(
  IN struct _IO_CSQ *Csq,
  IN PIRP Irp);

typedef struct _IO_CSQ {
  ULONG Type;
  PIO_CSQ_INSERT_IRP CsqInsertIrp;
  PIO_CSQ_REMOVE_IRP CsqRemoveIrp;
  PIO_CSQ_PEEK_NEXT_IRP CsqPeekNextIrp;
  PIO_CSQ_ACQUIRE_LOCK CsqAcquireLock;
  PIO_CSQ_RELEASE_LOCK CsqReleaseLock;
  PIO_CSQ_COMPLETE_CANCELED_IRP CsqCompleteCanceledIrp;
  PVOID ReservePointer;
} IO_CSQ, *PIO_CSQ;

typedef enum _BUS_QUERY_ID_TYPE {
  BusQueryDeviceID,
  BusQueryHardwareIDs,
  BusQueryCompatibleIDs,
  BusQueryInstanceID,
  BusQueryDeviceSerialNumber
} BUS_QUERY_ID_TYPE, *PBUS_QUERY_ID_TYPE;

typedef enum _DEVICE_TEXT_TYPE {
  DeviceTextDescription,
  DeviceTextLocationInformation
} DEVICE_TEXT_TYPE, *PDEVICE_TEXT_TYPE;

typedef BOOLEAN
(NTAPI *PGPE_SERVICE_ROUTINE)(
  PVOID,
  PVOID);

typedef NTSTATUS
(NTAPI *PGPE_CONNECT_VECTOR)(
  PDEVICE_OBJECT,
  ULONG,
  KINTERRUPT_MODE,
  BOOLEAN,
  PGPE_SERVICE_ROUTINE,
  PVOID,
  PVOID);

typedef NTSTATUS
(NTAPI *PGPE_DISCONNECT_VECTOR)(
  PVOID);

typedef NTSTATUS
(NTAPI *PGPE_ENABLE_EVENT)(
  PDEVICE_OBJECT,
  PVOID);

typedef NTSTATUS
(NTAPI *PGPE_DISABLE_EVENT)(
  PDEVICE_OBJECT,
  PVOID);

typedef NTSTATUS
(NTAPI *PGPE_CLEAR_STATUS)(
  PDEVICE_OBJECT,
  PVOID);

typedef VOID
(NTAPI *PDEVICE_NOTIFY_CALLBACK)(
  PVOID,
  ULONG);

typedef NTSTATUS
(NTAPI *PREGISTER_FOR_DEVICE_NOTIFICATIONS)(
  PDEVICE_OBJECT,
  PDEVICE_NOTIFY_CALLBACK,
  PVOID);

typedef VOID
(NTAPI *PUNREGISTER_FOR_DEVICE_NOTIFICATIONS)(
  PDEVICE_OBJECT,
  PDEVICE_NOTIFY_CALLBACK);

typedef struct _ACPI_INTERFACE_STANDARD {
  USHORT Size;
  USHORT Version;
  PVOID Context;
  PINTERFACE_REFERENCE InterfaceReference;
  PINTERFACE_DEREFERENCE InterfaceDereference;
  PGPE_CONNECT_VECTOR GpeConnectVector;
  PGPE_DISCONNECT_VECTOR GpeDisconnectVector;
  PGPE_ENABLE_EVENT GpeEnableEvent;
  PGPE_DISABLE_EVENT GpeDisableEvent;
  PGPE_CLEAR_STATUS GpeClearStatus;
  PREGISTER_FOR_DEVICE_NOTIFICATIONS RegisterForDeviceNotifications;
  PUNREGISTER_FOR_DEVICE_NOTIFICATIONS UnregisterForDeviceNotifications;
} ACPI_INTERFACE_STANDARD, *PACPI_INTERFACE_STANDARD;

typedef BOOLEAN
(NTAPI *PGPE_SERVICE_ROUTINE2)(
  PVOID ObjectContext,
  PVOID ServiceContext);

typedef NTSTATUS
(NTAPI *PGPE_CONNECT_VECTOR2)(
  PVOID Context,
  ULONG GpeNumber,
  KINTERRUPT_MODE Mode,
  BOOLEAN Shareable,
  PGPE_SERVICE_ROUTINE ServiceRoutine,
  PVOID ServiceContext,
  PVOID *ObjectContext);

typedef NTSTATUS
(NTAPI *PGPE_DISCONNECT_VECTOR2)(
  PVOID Context,
  PVOID ObjectContext);

typedef NTSTATUS
(NTAPI *PGPE_ENABLE_EVENT2)(
  PVOID Context,
  PVOID ObjectContext);

typedef NTSTATUS
(NTAPI *PGPE_DISABLE_EVENT2)(
  PVOID Context,
  PVOID ObjectContext);

typedef NTSTATUS
(NTAPI *PGPE_CLEAR_STATUS2)(
  PVOID Context,
  PVOID ObjectContext);

typedef VOID
(NTAPI *PDEVICE_NOTIFY_CALLBACK2)(
  PVOID NotificationContext,
  ULONG NotifyCode);

typedef NTSTATUS
(NTAPI *PREGISTER_FOR_DEVICE_NOTIFICATIONS2)(
  PVOID Context,
  PDEVICE_NOTIFY_CALLBACK2 NotificationHandler,
  PVOID NotificationContext);

typedef VOID
(NTAPI *PUNREGISTER_FOR_DEVICE_NOTIFICATIONS2)(
  PVOID Context);

typedef struct _ACPI_INTERFACE_STANDARD2 {
  USHORT Size;
  USHORT Version;
  PVOID Context;
  PINTERFACE_REFERENCE InterfaceReference;
  PINTERFACE_DEREFERENCE InterfaceDereference;
  PGPE_CONNECT_VECTOR2 GpeConnectVector;
  PGPE_DISCONNECT_VECTOR2 GpeDisconnectVector;
  PGPE_ENABLE_EVENT2 GpeEnableEvent;
  PGPE_DISABLE_EVENT2 GpeDisableEvent;
  PGPE_CLEAR_STATUS2 GpeClearStatus;
  PREGISTER_FOR_DEVICE_NOTIFICATIONS2 RegisterForDeviceNotifications;
  PUNREGISTER_FOR_DEVICE_NOTIFICATIONS2 UnregisterForDeviceNotifications;
} ACPI_INTERFACE_STANDARD2, *PACPI_INTERFACE_STANDARD2;

#if !defined(_AMD64_) && !defined(_IA64_)
#include <pshpack4.h>
#endif
typedef struct _IO_STACK_LOCATION {
  UCHAR MajorFunction;
  UCHAR MinorFunction;
  UCHAR Flags;
  UCHAR Control;
  union {
    struct {
      PIO_SECURITY_CONTEXT SecurityContext;
      ULONG Options;
      USHORT POINTER_ALIGNMENT FileAttributes;
      USHORT ShareAccess;
      ULONG POINTER_ALIGNMENT EaLength;
    } Create;
    struct {
      ULONG Length;
      ULONG POINTER_ALIGNMENT Key;
      LARGE_INTEGER ByteOffset;
    } Read;
    struct {
      ULONG Length;
      ULONG POINTER_ALIGNMENT Key;
      LARGE_INTEGER ByteOffset;
    } Write;
    struct {
      ULONG Length;
      PUNICODE_STRING FileName;
      FILE_INFORMATION_CLASS FileInformationClass;
      ULONG FileIndex;
    } QueryDirectory;
    struct {
      ULONG Length;
      ULONG CompletionFilter;
    } NotifyDirectory;
    struct {
      ULONG Length;
      FILE_INFORMATION_CLASS POINTER_ALIGNMENT FileInformationClass;
    } QueryFile;
    struct {
      ULONG Length;
      FILE_INFORMATION_CLASS POINTER_ALIGNMENT FileInformationClass;
      PFILE_OBJECT FileObject;
      _ANONYMOUS_UNION union {
        _ANONYMOUS_STRUCT struct {
          BOOLEAN ReplaceIfExists;
          BOOLEAN AdvanceOnly;
        } DUMMYSTRUCTNAME;
        ULONG ClusterCount;
        HANDLE DeleteHandle;
      } DUMMYUNIONNAME;
    } SetFile;
    struct {
      ULONG Length;
      PVOID EaList;
      ULONG EaListLength;
      ULONG EaIndex;
    } QueryEa;
    struct {
      ULONG Length;
    } SetEa;
    struct {
      ULONG Length;
      FS_INFORMATION_CLASS POINTER_ALIGNMENT FsInformationClass;
    } QueryVolume;
    struct {
      ULONG Length;
      FS_INFORMATION_CLASS FsInformationClass;
    } SetVolume;
    struct {
      ULONG OutputBufferLength;
      ULONG InputBufferLength;
      ULONG FsControlCode;
      PVOID Type3InputBuffer;
    } FileSystemControl;
    struct {
      PLARGE_INTEGER Length;
      ULONG Key;
      LARGE_INTEGER ByteOffset;
    } LockControl;
    struct {
      ULONG OutputBufferLength;
      ULONG POINTER_ALIGNMENT InputBufferLength;
      ULONG POINTER_ALIGNMENT IoControlCode;
      PVOID Type3InputBuffer;
    } DeviceIoControl;
    struct {
      SECURITY_INFORMATION SecurityInformation;
      ULONG POINTER_ALIGNMENT Length;
    } QuerySecurity;
    struct {
      SECURITY_INFORMATION SecurityInformation;
      PSECURITY_DESCRIPTOR SecurityDescriptor;
    } SetSecurity;
    struct {
      PVPB Vpb;
      PDEVICE_OBJECT DeviceObject;
    } MountVolume;
    struct {
      PVPB Vpb;
      PDEVICE_OBJECT DeviceObject;
    } VerifyVolume;
    struct {
      struct _SCSI_REQUEST_BLOCK *Srb;
    } Scsi;
    struct {
      ULONG Length;
      PSID StartSid;
      struct _FILE_GET_QUOTA_INFORMATION *SidList;
      ULONG SidListLength;
    } QueryQuota;
    struct {
      ULONG Length;
    } SetQuota;
    struct {
      DEVICE_RELATION_TYPE Type;
    } QueryDeviceRelations;
    struct {
      CONST GUID *InterfaceType;
      USHORT Size;
      USHORT Version;
      PINTERFACE Interface;
      PVOID InterfaceSpecificData;
    } QueryInterface;
    struct {
      PDEVICE_CAPABILITIES Capabilities;
    } DeviceCapabilities;
    struct {
      PIO_RESOURCE_REQUIREMENTS_LIST IoResourceRequirementList;
    } FilterResourceRequirements;
    struct {
      ULONG WhichSpace;
      PVOID Buffer;
      ULONG Offset;
      ULONG POINTER_ALIGNMENT Length;
    } ReadWriteConfig;
    struct {
      BOOLEAN Lock;
    } SetLock;
    struct {
      BUS_QUERY_ID_TYPE IdType;
    } QueryId;
    struct {
      DEVICE_TEXT_TYPE DeviceTextType;
      LCID POINTER_ALIGNMENT LocaleId;
    } QueryDeviceText;
    struct {
      BOOLEAN InPath;
      BOOLEAN Reserved[3];
      DEVICE_USAGE_NOTIFICATION_TYPE POINTER_ALIGNMENT Type;
    } UsageNotification;
    struct {
      SYSTEM_POWER_STATE PowerState;
    } WaitWake;
    struct {
      PPOWER_SEQUENCE PowerSequence;
    } PowerSequence;
    struct {
      ULONG SystemContext;
      POWER_STATE_TYPE POINTER_ALIGNMENT Type;
      POWER_STATE POINTER_ALIGNMENT State;
      POWER_ACTION POINTER_ALIGNMENT ShutdownType;
    } Power;
    struct {
      PCM_RESOURCE_LIST AllocatedResources;
      PCM_RESOURCE_LIST AllocatedResourcesTranslated;
    } StartDevice;
    struct {
      ULONG_PTR ProviderId;
      PVOID DataPath;
      ULONG BufferSize;
      PVOID Buffer;
    } WMI;
    struct {
      PVOID Argument1;
      PVOID Argument2;
      PVOID Argument3;
      PVOID Argument4;
    } Others;
  } Parameters;
  PDEVICE_OBJECT DeviceObject;
  PFILE_OBJECT FileObject;
  PIO_COMPLETION_ROUTINE CompletionRoutine;
  PVOID Context;
} IO_STACK_LOCATION, *PIO_STACK_LOCATION;
#if !defined(_AMD64_) && !defined(_IA64_)
#include <poppack.h>
#endif

/* IO_STACK_LOCATION.Control */

#define SL_PENDING_RETURNED               0x01
#define SL_ERROR_RETURNED                 0x02
#define SL_INVOKE_ON_CANCEL               0x20
#define SL_INVOKE_ON_SUCCESS              0x40
#define SL_INVOKE_ON_ERROR                0x80

#define METHOD_BUFFERED                   0
#define METHOD_IN_DIRECT                  1
#define METHOD_OUT_DIRECT                 2
#define METHOD_NEITHER                    3

#define METHOD_DIRECT_TO_HARDWARE       METHOD_IN_DIRECT
#define METHOD_DIRECT_FROM_HARDWARE     METHOD_OUT_DIRECT

#define FILE_SUPERSEDED                   0x00000000
#define FILE_OPENED                       0x00000001
#define FILE_CREATED                      0x00000002
#define FILE_OVERWRITTEN                  0x00000003
#define FILE_EXISTS                       0x00000004
#define FILE_DOES_NOT_EXIST               0x00000005

#define FILE_USE_FILE_POINTER_POSITION    0xfffffffe
#define FILE_WRITE_TO_END_OF_FILE         0xffffffff

/* also in winnt.h */
#define FILE_LIST_DIRECTORY               0x00000001
#define FILE_READ_DATA                    0x00000001
#define FILE_ADD_FILE                     0x00000002
#define FILE_WRITE_DATA                   0x00000002
#define FILE_ADD_SUBDIRECTORY             0x00000004
#define FILE_APPEND_DATA                  0x00000004
#define FILE_CREATE_PIPE_INSTANCE         0x00000004
#define FILE_READ_EA                      0x00000008
#define FILE_WRITE_EA                     0x00000010
#define FILE_EXECUTE                      0x00000020
#define FILE_TRAVERSE                     0x00000020
#define FILE_DELETE_CHILD                 0x00000040
#define FILE_READ_ATTRIBUTES              0x00000080
#define FILE_WRITE_ATTRIBUTES             0x00000100

#define FILE_SHARE_READ                   0x00000001
#define FILE_SHARE_WRITE                  0x00000002
#define FILE_SHARE_DELETE                 0x00000004
#define FILE_SHARE_VALID_FLAGS            0x00000007

#define FILE_ATTRIBUTE_READONLY           0x00000001
#define FILE_ATTRIBUTE_HIDDEN             0x00000002
#define FILE_ATTRIBUTE_SYSTEM             0x00000004
#define FILE_ATTRIBUTE_DIRECTORY          0x00000010
#define FILE_ATTRIBUTE_ARCHIVE            0x00000020
#define FILE_ATTRIBUTE_DEVICE             0x00000040
#define FILE_ATTRIBUTE_NORMAL             0x00000080
#define FILE_ATTRIBUTE_TEMPORARY          0x00000100
#define FILE_ATTRIBUTE_SPARSE_FILE        0x00000200
#define FILE_ATTRIBUTE_REPARSE_POINT      0x00000400
#define FILE_ATTRIBUTE_COMPRESSED         0x00000800
#define FILE_ATTRIBUTE_OFFLINE            0x00001000
#define FILE_ATTRIBUTE_NOT_CONTENT_INDEXED 0x00002000
#define FILE_ATTRIBUTE_ENCRYPTED          0x00004000
#define FILE_ATTRIBUTE_VIRTUAL            0x00010000

#define FILE_ATTRIBUTE_VALID_FLAGS        0x00007fb7
#define FILE_ATTRIBUTE_VALID_SET_FLAGS    0x000031a7

#define FILE_VALID_OPTION_FLAGS           0x00ffffff
#define FILE_VALID_PIPE_OPTION_FLAGS      0x00000032
#define FILE_VALID_MAILSLOT_OPTION_FLAGS  0x00000032
#define FILE_VALID_SET_FLAGS              0x00000036

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

#define FILE_ANY_ACCESS                   0x00000000
#define FILE_SPECIAL_ACCESS               FILE_ANY_ACCESS
#define FILE_READ_ACCESS                  0x00000001
#define FILE_WRITE_ACCESS                 0x00000002

#define FILE_ALL_ACCESS \
  (STANDARD_RIGHTS_REQUIRED | \
   SYNCHRONIZE | \
   0x1FF)

#define FILE_GENERIC_EXECUTE \
  (STANDARD_RIGHTS_EXECUTE | \
   FILE_READ_ATTRIBUTES | \
   FILE_EXECUTE | \
   SYNCHRONIZE)

#define FILE_GENERIC_READ \
  (STANDARD_RIGHTS_READ | \
   FILE_READ_DATA | \
   FILE_READ_ATTRIBUTES | \
   FILE_READ_EA | \
   SYNCHRONIZE)

#define FILE_GENERIC_WRITE \
  (STANDARD_RIGHTS_WRITE | \
   FILE_WRITE_DATA | \
   FILE_WRITE_ATTRIBUTES | \
   FILE_WRITE_EA | \
   FILE_APPEND_DATA | \
   SYNCHRONIZE)

/* end winnt.h */

#define WMIREG_ACTION_REGISTER      1
#define WMIREG_ACTION_DEREGISTER    2
#define WMIREG_ACTION_REREGISTER    3
#define WMIREG_ACTION_UPDATE_GUIDS  4
#define WMIREG_ACTION_BLOCK_IRPS    5

#define WMIREGISTER                 0
#define WMIUPDATE                   1

typedef VOID
(NTAPI FWMI_NOTIFICATION_CALLBACK)(
  PVOID Wnode,
  PVOID Context);
typedef FWMI_NOTIFICATION_CALLBACK *WMI_NOTIFICATION_CALLBACK;

#ifndef _PCI_X_
#define _PCI_X_

typedef struct _PCI_SLOT_NUMBER {
  union {
    struct {
      ULONG DeviceNumber:5;
      ULONG FunctionNumber:3;
      ULONG Reserved:24;
    } bits;
    ULONG AsULONG;
  } u;
} PCI_SLOT_NUMBER, *PPCI_SLOT_NUMBER;

#define PCI_TYPE0_ADDRESSES               6
#define PCI_TYPE1_ADDRESSES               2
#define PCI_TYPE2_ADDRESSES               5

typedef struct _PCI_COMMON_HEADER {
  PCI_COMMON_HEADER_LAYOUT
} PCI_COMMON_HEADER, *PPCI_COMMON_HEADER;

#ifdef __cplusplus
typedef struct _PCI_COMMON_CONFIG {
  PCI_COMMON_HEADER_LAYOUT
  UCHAR DeviceSpecific[192];
} PCI_COMMON_CONFIG, *PPCI_COMMON_CONFIG;
#else
typedef struct _PCI_COMMON_CONFIG {
  __extension__ struct {
    PCI_COMMON_HEADER_LAYOUT
  };
  UCHAR DeviceSpecific[192];
} PCI_COMMON_CONFIG, *PPCI_COMMON_CONFIG;
#endif

#define PCI_COMMON_HDR_LENGTH (FIELD_OFFSET(PCI_COMMON_CONFIG, DeviceSpecific))

#define PCI_EXTENDED_CONFIG_LENGTH               0x1000

#define PCI_MAX_DEVICES        32
#define PCI_MAX_FUNCTION       8
#define PCI_MAX_BRIDGE_NUMBER  0xFF
#define PCI_INVALID_VENDORID   0xFFFF

/* PCI_COMMON_CONFIG.HeaderType */
#define PCI_MULTIFUNCTION                 0x80
#define PCI_DEVICE_TYPE                   0x00
#define PCI_BRIDGE_TYPE                   0x01
#define PCI_CARDBUS_BRIDGE_TYPE           0x02

#define PCI_CONFIGURATION_TYPE(PciData) \
  (((PPCI_COMMON_CONFIG) (PciData))->HeaderType & ~PCI_MULTIFUNCTION)

#define PCI_MULTIFUNCTION_DEVICE(PciData) \
  ((((PPCI_COMMON_CONFIG) (PciData))->HeaderType & PCI_MULTIFUNCTION) != 0)

/* PCI_COMMON_CONFIG.Command */
#define PCI_ENABLE_IO_SPACE               0x0001
#define PCI_ENABLE_MEMORY_SPACE           0x0002
#define PCI_ENABLE_BUS_MASTER             0x0004
#define PCI_ENABLE_SPECIAL_CYCLES         0x0008
#define PCI_ENABLE_WRITE_AND_INVALIDATE   0x0010
#define PCI_ENABLE_VGA_COMPATIBLE_PALETTE 0x0020
#define PCI_ENABLE_PARITY                 0x0040
#define PCI_ENABLE_WAIT_CYCLE             0x0080
#define PCI_ENABLE_SERR                   0x0100
#define PCI_ENABLE_FAST_BACK_TO_BACK      0x0200
#define PCI_DISABLE_LEVEL_INTERRUPT       0x0400

/* PCI_COMMON_CONFIG.Status */
#define PCI_STATUS_INTERRUPT_PENDING      0x0008
#define PCI_STATUS_CAPABILITIES_LIST      0x0010
#define PCI_STATUS_66MHZ_CAPABLE          0x0020
#define PCI_STATUS_UDF_SUPPORTED          0x0040
#define PCI_STATUS_FAST_BACK_TO_BACK      0x0080
#define PCI_STATUS_DATA_PARITY_DETECTED   0x0100
#define PCI_STATUS_DEVSEL                 0x0600
#define PCI_STATUS_SIGNALED_TARGET_ABORT  0x0800
#define PCI_STATUS_RECEIVED_TARGET_ABORT  0x1000
#define PCI_STATUS_RECEIVED_MASTER_ABORT  0x2000
#define PCI_STATUS_SIGNALED_SYSTEM_ERROR  0x4000
#define PCI_STATUS_DETECTED_PARITY_ERROR  0x8000

/* IO_STACK_LOCATION.Parameters.ReadWriteControl.WhichSpace */

#define PCI_WHICHSPACE_CONFIG             0x0
#define PCI_WHICHSPACE_ROM                0x52696350 /* 'PciR' */

#define PCI_CAPABILITY_ID_POWER_MANAGEMENT  0x01
#define PCI_CAPABILITY_ID_AGP               0x02
#define PCI_CAPABILITY_ID_VPD               0x03
#define PCI_CAPABILITY_ID_SLOT_ID           0x04
#define PCI_CAPABILITY_ID_MSI               0x05
#define PCI_CAPABILITY_ID_CPCI_HOTSWAP      0x06
#define PCI_CAPABILITY_ID_PCIX              0x07
#define PCI_CAPABILITY_ID_HYPERTRANSPORT    0x08
#define PCI_CAPABILITY_ID_VENDOR_SPECIFIC   0x09
#define PCI_CAPABILITY_ID_DEBUG_PORT        0x0A
#define PCI_CAPABILITY_ID_CPCI_RES_CTRL     0x0B
#define PCI_CAPABILITY_ID_SHPC              0x0C
#define PCI_CAPABILITY_ID_P2P_SSID          0x0D
#define PCI_CAPABILITY_ID_AGP_TARGET        0x0E
#define PCI_CAPABILITY_ID_SECURE            0x0F
#define PCI_CAPABILITY_ID_PCI_EXPRESS       0x10
#define PCI_CAPABILITY_ID_MSIX              0x11

typedef struct _PCI_CAPABILITIES_HEADER {
  UCHAR CapabilityID;
  UCHAR Next;
} PCI_CAPABILITIES_HEADER, *PPCI_CAPABILITIES_HEADER;

typedef struct _PCI_PMC {
  UCHAR Version:3;
  UCHAR PMEClock:1;
  UCHAR Rsvd1:1;
  UCHAR DeviceSpecificInitialization:1;
  UCHAR Rsvd2:2;
  struct _PM_SUPPORT {
    UCHAR Rsvd2:1;
    UCHAR D1:1;
    UCHAR D2:1;
    UCHAR PMED0:1;
    UCHAR PMED1:1;
    UCHAR PMED2:1;
    UCHAR PMED3Hot:1;
    UCHAR PMED3Cold:1;
  } Support;
} PCI_PMC, *PPCI_PMC;

typedef struct _PCI_PMCSR {
  USHORT PowerState:2;
  USHORT Rsvd1:6;
  USHORT PMEEnable:1;
  USHORT DataSelect:4;
  USHORT DataScale:2;
  USHORT PMEStatus:1;
} PCI_PMCSR, *PPCI_PMCSR;

typedef struct _PCI_PMCSR_BSE {
  UCHAR Rsvd1:6;
  UCHAR D3HotSupportsStopClock:1;
  UCHAR BusPowerClockControlEnabled:1;
} PCI_PMCSR_BSE, *PPCI_PMCSR_BSE;

typedef struct _PCI_PM_CAPABILITY {
  PCI_CAPABILITIES_HEADER Header;
  union {
    PCI_PMC Capabilities;
    USHORT AsUSHORT;
  } PMC;
    union {
      PCI_PMCSR ControlStatus;
      USHORT AsUSHORT;
    } PMCSR;
    union {
      PCI_PMCSR_BSE BridgeSupport;
      UCHAR AsUCHAR;
    } PMCSR_BSE;
  UCHAR Data;
} PCI_PM_CAPABILITY, *PPCI_PM_CAPABILITY;

typedef struct {
  PCI_CAPABILITIES_HEADER Header;
  union {
    struct {
      USHORT DataParityErrorRecoveryEnable:1;
      USHORT EnableRelaxedOrdering:1;
      USHORT MaxMemoryReadByteCount:2;
      USHORT MaxOutstandingSplitTransactions:3;
      USHORT Reserved:9;
    } bits;
    USHORT AsUSHORT;
  } Command;
  union {
    struct {
      ULONG FunctionNumber:3;
      ULONG DeviceNumber:5;
      ULONG BusNumber:8;
      ULONG Device64Bit:1;
      ULONG Capable133MHz:1;
      ULONG SplitCompletionDiscarded:1;
      ULONG UnexpectedSplitCompletion:1;
      ULONG DeviceComplexity:1;
      ULONG DesignedMaxMemoryReadByteCount:2;
      ULONG DesignedMaxOutstandingSplitTransactions:3;
      ULONG DesignedMaxCumulativeReadSize:3;
      ULONG ReceivedSplitCompletionErrorMessage:1;
      ULONG CapablePCIX266:1;
      ULONG CapablePCIX533:1;
      } bits;
    ULONG AsULONG;
  } Status;
} PCI_X_CAPABILITY, *PPCI_X_CAPABILITY;

#define PCI_EXPRESS_ADVANCED_ERROR_REPORTING_CAP_ID                     0x0001
#define PCI_EXPRESS_VIRTUAL_CHANNEL_CAP_ID                              0x0002
#define PCI_EXPRESS_DEVICE_SERIAL_NUMBER_CAP_ID                         0x0003
#define PCI_EXPRESS_POWER_BUDGETING_CAP_ID                              0x0004
#define PCI_EXPRESS_RC_LINK_DECLARATION_CAP_ID                          0x0005
#define PCI_EXPRESS_RC_INTERNAL_LINK_CONTROL_CAP_ID                     0x0006
#define PCI_EXPRESS_RC_EVENT_COLLECTOR_ENDPOINT_ASSOCIATION_CAP_ID      0x0007
#define PCI_EXPRESS_MFVC_CAP_ID                                         0x0008
#define PCI_EXPRESS_VC_AND_MFVC_CAP_ID                                  0x0009
#define PCI_EXPRESS_RCRB_HEADER_CAP_ID                                  0x000A
#define PCI_EXPRESS_SINGLE_ROOT_IO_VIRTUALIZATION_CAP_ID                0x0010

typedef struct _PCI_EXPRESS_ENHANCED_CAPABILITY_HEADER {
  USHORT CapabilityID;
  USHORT Version:4;
  USHORT Next:12;
} PCI_EXPRESS_ENHANCED_CAPABILITY_HEADER, *PPCI_EXPRESS_ENHANCED_CAPABILITY_HEADER;

typedef struct _PCI_EXPRESS_SERIAL_NUMBER_CAPABILITY {
  PCI_EXPRESS_ENHANCED_CAPABILITY_HEADER Header;
  ULONG LowSerialNumber;
  ULONG HighSerialNumber;
} PCI_EXPRESS_SERIAL_NUMBER_CAPABILITY, *PPCI_EXPRESS_SERIAL_NUMBER_CAPABILITY;

typedef union _PCI_EXPRESS_UNCORRECTABLE_ERROR_STATUS {
  _ANONYMOUS_STRUCT struct {
    ULONG Undefined:1;
    ULONG Reserved1:3;
    ULONG DataLinkProtocolError:1;
    ULONG SurpriseDownError:1;
    ULONG Reserved2:6;
    ULONG PoisonedTLP:1;
    ULONG FlowControlProtocolError:1;
    ULONG CompletionTimeout:1;
    ULONG CompleterAbort:1;
    ULONG UnexpectedCompletion:1;
    ULONG ReceiverOverflow:1;
    ULONG MalformedTLP:1;
    ULONG ECRCError:1;
    ULONG UnsupportedRequestError:1;
    ULONG Reserved3:11;
  } DUMMYSTRUCTNAME;
  ULONG AsULONG;
} PCI_EXPRESS_UNCORRECTABLE_ERROR_STATUS, *PPCI_EXPRESS_UNCORRECTABLE_ERROR_STATUS;

typedef union _PCI_EXPRESS_UNCORRECTABLE_ERROR_MASK {
  _ANONYMOUS_STRUCT struct {
    ULONG Undefined:1;
    ULONG Reserved1:3;
    ULONG DataLinkProtocolError:1;
    ULONG SurpriseDownError:1;
    ULONG Reserved2:6;
    ULONG PoisonedTLP:1;
    ULONG FlowControlProtocolError:1;
    ULONG CompletionTimeout:1;
    ULONG CompleterAbort:1;
    ULONG UnexpectedCompletion:1;
    ULONG ReceiverOverflow:1;
    ULONG MalformedTLP:1;
    ULONG ECRCError:1;
    ULONG UnsupportedRequestError:1;
    ULONG Reserved3:11;
  } DUMMYSTRUCTNAME;
  ULONG AsULONG;
} PCI_EXPRESS_UNCORRECTABLE_ERROR_MASK, *PPCI_EXPRESS_UNCORRECTABLE_ERROR_MASK;

typedef union _PCI_EXPRESS_UNCORRECTABLE_ERROR_SEVERITY {
  _ANONYMOUS_STRUCT struct {
    ULONG Undefined:1;
    ULONG Reserved1:3;
    ULONG DataLinkProtocolError:1;
    ULONG SurpriseDownError:1;
    ULONG Reserved2:6;
    ULONG PoisonedTLP:1;
    ULONG FlowControlProtocolError:1;
    ULONG CompletionTimeout:1;
    ULONG CompleterAbort:1;
    ULONG UnexpectedCompletion:1;
    ULONG ReceiverOverflow:1;
    ULONG MalformedTLP:1;
    ULONG ECRCError:1;
    ULONG UnsupportedRequestError:1;
    ULONG Reserved3:11;
  } DUMMYSTRUCTNAME;
  ULONG AsULONG;
} PCI_EXPRESS_UNCORRECTABLE_ERROR_SEVERITY, *PPCI_EXPRESS_UNCORRECTABLE_ERROR_SEVERITY;

typedef union _PCI_EXPRESS_CORRECTABLE_ERROR_STATUS {
  _ANONYMOUS_STRUCT struct {
    ULONG ReceiverError:1;
    ULONG Reserved1:5;
    ULONG BadTLP:1;
    ULONG BadDLLP:1;
    ULONG ReplayNumRollover:1;
    ULONG Reserved2:3;
    ULONG ReplayTimerTimeout:1;
    ULONG AdvisoryNonFatalError:1;
    ULONG Reserved3:18;
  } DUMMYSTRUCTNAME;
  ULONG AsULONG;
} PCI_EXPRESS_CORRECTABLE_ERROR_STATUS, *PPCI_CORRECTABLE_ERROR_STATUS;

typedef union _PCI_EXPRESS_CORRECTABLE_ERROR_MASK {
  _ANONYMOUS_STRUCT struct {
    ULONG ReceiverError:1;
    ULONG Reserved1:5;
    ULONG BadTLP:1;
    ULONG BadDLLP:1;
    ULONG ReplayNumRollover:1;
    ULONG Reserved2:3;
    ULONG ReplayTimerTimeout:1;
    ULONG AdvisoryNonFatalError:1;
    ULONG Reserved3:18;
  } DUMMYSTRUCTNAME;
  ULONG AsULONG;
} PCI_EXPRESS_CORRECTABLE_ERROR_MASK, *PPCI_CORRECTABLE_ERROR_MASK;

typedef union _PCI_EXPRESS_AER_CAPABILITIES {
  _ANONYMOUS_STRUCT struct {
    ULONG FirstErrorPointer:5;
    ULONG ECRCGenerationCapable:1;
    ULONG ECRCGenerationEnable:1;
    ULONG ECRCCheckCapable:1;
    ULONG ECRCCheckEnable:1;
    ULONG Reserved:23;
  } DUMMYSTRUCTNAME;
  ULONG AsULONG;
} PCI_EXPRESS_AER_CAPABILITIES, *PPCI_EXPRESS_AER_CAPABILITIES;

typedef union _PCI_EXPRESS_ROOT_ERROR_COMMAND {
  _ANONYMOUS_STRUCT struct {
    ULONG CorrectableErrorReportingEnable:1;
    ULONG NonFatalErrorReportingEnable:1;
    ULONG FatalErrorReportingEnable:1;
    ULONG Reserved:29;
  } DUMMYSTRUCTNAME;
  ULONG AsULONG;
} PCI_EXPRESS_ROOT_ERROR_COMMAND, *PPCI_EXPRESS_ROOT_ERROR_COMMAND;

typedef union _PCI_EXPRESS_ROOT_ERROR_STATUS {
  _ANONYMOUS_STRUCT struct {
    ULONG CorrectableErrorReceived:1;
    ULONG MultipleCorrectableErrorsReceived:1;
    ULONG UncorrectableErrorReceived:1;
    ULONG MultipleUncorrectableErrorsReceived:1;
    ULONG FirstUncorrectableFatal:1;
    ULONG NonFatalErrorMessagesReceived:1;
    ULONG FatalErrorMessagesReceived:1;
    ULONG Reserved:20;
    ULONG AdvancedErrorInterruptMessageNumber:5;
  } DUMMYSTRUCTNAME;
  ULONG AsULONG;
} PCI_EXPRESS_ROOT_ERROR_STATUS, *PPCI_EXPRESS_ROOT_ERROR_STATUS;

typedef union _PCI_EXPRESS_ERROR_SOURCE_ID {
  _ANONYMOUS_STRUCT struct {
    USHORT CorrectableSourceIdFun:3;
    USHORT CorrectableSourceIdDev:5;
    USHORT CorrectableSourceIdBus:8;
    USHORT UncorrectableSourceIdFun:3;
    USHORT UncorrectableSourceIdDev:5;
    USHORT UncorrectableSourceIdBus:8;
  } DUMMYSTRUCTNAME;
  ULONG AsULONG;
} PCI_EXPRESS_ERROR_SOURCE_ID, *PPCI_EXPRESS_ERROR_SOURCE_ID;

typedef union _PCI_EXPRESS_SEC_UNCORRECTABLE_ERROR_STATUS {
  _ANONYMOUS_STRUCT struct {
    ULONG TargetAbortOnSplitCompletion:1;
    ULONG MasterAbortOnSplitCompletion:1;
    ULONG ReceivedTargetAbort:1;
    ULONG ReceivedMasterAbort:1;
    ULONG RsvdZ:1;
    ULONG UnexpectedSplitCompletionError:1;
    ULONG UncorrectableSplitCompletion:1;
    ULONG UncorrectableDataError:1;
    ULONG UncorrectableAttributeError:1;
    ULONG UncorrectableAddressError:1;
    ULONG DelayedTransactionDiscardTimerExpired:1;
    ULONG PERRAsserted:1;
    ULONG SERRAsserted:1;
    ULONG InternalBridgeError:1;
    ULONG Reserved:18;
  } DUMMYSTRUCTNAME;
  ULONG AsULONG;
} PCI_EXPRESS_SEC_UNCORRECTABLE_ERROR_STATUS, *PPCI_EXPRESS_SEC_UNCORRECTABLE_ERROR_STATUS;

typedef union _PCI_EXPRESS_SEC_UNCORRECTABLE_ERROR_MASK {
  _ANONYMOUS_STRUCT struct {
    ULONG TargetAbortOnSplitCompletion:1;
    ULONG MasterAbortOnSplitCompletion:1;
    ULONG ReceivedTargetAbort:1;
    ULONG ReceivedMasterAbort:1;
    ULONG RsvdZ:1;
    ULONG UnexpectedSplitCompletionError:1;
    ULONG UncorrectableSplitCompletion:1;
    ULONG UncorrectableDataError:1;
    ULONG UncorrectableAttributeError:1;
    ULONG UncorrectableAddressError:1;
    ULONG DelayedTransactionDiscardTimerExpired:1;
    ULONG PERRAsserted:1;
    ULONG SERRAsserted:1;
    ULONG InternalBridgeError:1;
    ULONG Reserved:18;
  } DUMMYSTRUCTNAME;
  ULONG AsULONG;
} PCI_EXPRESS_SEC_UNCORRECTABLE_ERROR_MASK, *PPCI_EXPRESS_SEC_UNCORRECTABLE_ERROR_MASK;

typedef union _PCI_EXPRESS_SEC_UNCORRECTABLE_ERROR_SEVERITY {
  _ANONYMOUS_STRUCT struct {
    ULONG TargetAbortOnSplitCompletion:1;
    ULONG MasterAbortOnSplitCompletion:1;
    ULONG ReceivedTargetAbort:1;
    ULONG ReceivedMasterAbort:1;
    ULONG RsvdZ:1;
    ULONG UnexpectedSplitCompletionError:1;
    ULONG UncorrectableSplitCompletion:1;
    ULONG UncorrectableDataError:1;
    ULONG UncorrectableAttributeError:1;
    ULONG UncorrectableAddressError:1;
    ULONG DelayedTransactionDiscardTimerExpired:1;
    ULONG PERRAsserted:1;
    ULONG SERRAsserted:1;
    ULONG InternalBridgeError:1;
    ULONG Reserved:18;
  } DUMMYSTRUCTNAME;
  ULONG AsULONG;
} PCI_EXPRESS_SEC_UNCORRECTABLE_ERROR_SEVERITY, *PPCI_EXPRESS_SEC_UNCORRECTABLE_ERROR_SEVERITY;

typedef union _PCI_EXPRESS_SEC_AER_CAPABILITIES {
  _ANONYMOUS_STRUCT struct {
    ULONG SecondaryUncorrectableFirstErrorPtr:5;
    ULONG Reserved:27;
  } DUMMYSTRUCTNAME;
  ULONG AsULONG;
} PCI_EXPRESS_SEC_AER_CAPABILITIES, *PPCI_EXPRESS_SEC_AER_CAPABILITIES;

#define ROOT_CMD_ENABLE_CORRECTABLE_ERROR_REPORTING  0x00000001
#define ROOT_CMD_ENABLE_NONFATAL_ERROR_REPORTING     0x00000002
#define ROOT_CMD_ENABLE_FATAL_ERROR_REPORTING        0x00000004

#define ROOT_CMD_ERROR_REPORTING_ENABLE_MASK \
    (ROOT_CMD_ENABLE_FATAL_ERROR_REPORTING | \
     ROOT_CMD_ENABLE_NONFATAL_ERROR_REPORTING | \
     ROOT_CMD_ENABLE_CORRECTABLE_ERROR_REPORTING)

typedef struct _PCI_EXPRESS_AER_CAPABILITY {
  PCI_EXPRESS_ENHANCED_CAPABILITY_HEADER Header;
  PCI_EXPRESS_UNCORRECTABLE_ERROR_STATUS UncorrectableErrorStatus;
  PCI_EXPRESS_UNCORRECTABLE_ERROR_MASK UncorrectableErrorMask;
  PCI_EXPRESS_UNCORRECTABLE_ERROR_SEVERITY UncorrectableErrorSeverity;
  PCI_EXPRESS_CORRECTABLE_ERROR_STATUS CorrectableErrorStatus;
  PCI_EXPRESS_CORRECTABLE_ERROR_MASK CorrectableErrorMask;
  PCI_EXPRESS_AER_CAPABILITIES CapabilitiesAndControl;
  ULONG HeaderLog[4];
  PCI_EXPRESS_SEC_UNCORRECTABLE_ERROR_STATUS SecUncorrectableErrorStatus;
  PCI_EXPRESS_SEC_UNCORRECTABLE_ERROR_MASK SecUncorrectableErrorMask;
  PCI_EXPRESS_SEC_UNCORRECTABLE_ERROR_SEVERITY SecUncorrectableErrorSeverity;
  PCI_EXPRESS_SEC_AER_CAPABILITIES SecCapabilitiesAndControl;
  ULONG SecHeaderLog[4];
} PCI_EXPRESS_AER_CAPABILITY, *PPCI_EXPRESS_AER_CAPABILITY;

typedef struct _PCI_EXPRESS_ROOTPORT_AER_CAPABILITY {
  PCI_EXPRESS_ENHANCED_CAPABILITY_HEADER Header;
  PCI_EXPRESS_UNCORRECTABLE_ERROR_STATUS UncorrectableErrorStatus;
  PCI_EXPRESS_UNCORRECTABLE_ERROR_MASK UncorrectableErrorMask;
  PCI_EXPRESS_UNCORRECTABLE_ERROR_SEVERITY UncorrectableErrorSeverity;
  PCI_EXPRESS_CORRECTABLE_ERROR_STATUS CorrectableErrorStatus;
  PCI_EXPRESS_CORRECTABLE_ERROR_MASK CorrectableErrorMask;
  PCI_EXPRESS_AER_CAPABILITIES CapabilitiesAndControl;
  ULONG HeaderLog[4];
  PCI_EXPRESS_ROOT_ERROR_COMMAND RootErrorCommand;
  PCI_EXPRESS_ROOT_ERROR_STATUS RootErrorStatus;
  PCI_EXPRESS_ERROR_SOURCE_ID ErrorSourceId;
} PCI_EXPRESS_ROOTPORT_AER_CAPABILITY, *PPCI_EXPRESS_ROOTPORT_AER_CAPABILITY;

typedef struct _PCI_EXPRESS_BRIDGE_AER_CAPABILITY {
  PCI_EXPRESS_ENHANCED_CAPABILITY_HEADER Header;
  PCI_EXPRESS_UNCORRECTABLE_ERROR_STATUS UncorrectableErrorStatus;
  PCI_EXPRESS_UNCORRECTABLE_ERROR_MASK UncorrectableErrorMask;
  PCI_EXPRESS_UNCORRECTABLE_ERROR_SEVERITY UncorrectableErrorSeverity;
  PCI_EXPRESS_CORRECTABLE_ERROR_STATUS CorrectableErrorStatus;
  PCI_EXPRESS_CORRECTABLE_ERROR_MASK CorrectableErrorMask;
  PCI_EXPRESS_AER_CAPABILITIES CapabilitiesAndControl;
  ULONG HeaderLog[4];
  PCI_EXPRESS_SEC_UNCORRECTABLE_ERROR_STATUS SecUncorrectableErrorStatus;
  PCI_EXPRESS_SEC_UNCORRECTABLE_ERROR_MASK SecUncorrectableErrorMask;
  PCI_EXPRESS_SEC_UNCORRECTABLE_ERROR_SEVERITY SecUncorrectableErrorSeverity;
  PCI_EXPRESS_SEC_AER_CAPABILITIES SecCapabilitiesAndControl;
  ULONG SecHeaderLog[4];
} PCI_EXPRESS_BRIDGE_AER_CAPABILITY, *PPCI_EXPRESS_BRIDGE_AER_CAPABILITY;

typedef union _PCI_EXPRESS_SRIOV_CAPS {
  _ANONYMOUS_STRUCT struct {
    ULONG VFMigrationCapable:1;
    ULONG Reserved1:20;
    ULONG VFMigrationInterruptNumber:11;
  } DUMMYSTRUCTNAME;
  ULONG AsULONG;
} PCI_EXPRESS_SRIOV_CAPS, *PPCI_EXPRESS_SRIOV_CAPS;

typedef union _PCI_EXPRESS_SRIOV_CONTROL {
  _ANONYMOUS_STRUCT struct {
    USHORT VFEnable:1;
    USHORT VFMigrationEnable:1;
    USHORT VFMigrationInterruptEnable:1;
    USHORT VFMemorySpaceEnable:1;
    USHORT ARICapableHierarchy:1;
    USHORT Reserved1:11;
  } DUMMYSTRUCTNAME;
  USHORT AsUSHORT;
} PCI_EXPRESS_SRIOV_CONTROL, *PPCI_EXPRESS_SRIOV_CONTROL;

typedef union _PCI_EXPRESS_SRIOV_STATUS {
  _ANONYMOUS_STRUCT struct {
    USHORT VFMigrationStatus:1;
    USHORT Reserved1:15;
  } DUMMYSTRUCTNAME;
  USHORT AsUSHORT;
} PCI_EXPRESS_SRIOV_STATUS, *PPCI_EXPRESS_SRIOV_STATUS;

typedef union _PCI_EXPRESS_SRIOV_MIGRATION_STATE_ARRAY {
  _ANONYMOUS_STRUCT struct {
    ULONG VFMigrationStateBIR:3;
    ULONG VFMigrationStateOffset:29;
  } DUMMYSTRUCTNAME;
  ULONG AsULONG;
} PCI_EXPRESS_SRIOV_MIGRATION_STATE_ARRAY, *PPCI_EXPRESS_SRIOV_MIGRATION_STATE_ARRAY;

typedef struct _PCI_EXPRESS_SRIOV_CAPABILITY {
  PCI_EXPRESS_ENHANCED_CAPABILITY_HEADER Header;
  PCI_EXPRESS_SRIOV_CAPS SRIOVCapabilities;
  PCI_EXPRESS_SRIOV_CONTROL SRIOVControl;
  PCI_EXPRESS_SRIOV_STATUS SRIOVStatus;
  USHORT InitialVFs;
  USHORT TotalVFs;
  USHORT NumVFs;
  UCHAR FunctionDependencyLink;
  UCHAR RsvdP1;
  USHORT FirstVFOffset;
  USHORT VFStride;
  USHORT RsvdP2;
  USHORT VFDeviceId;
  ULONG SupportedPageSizes;
  ULONG SystemPageSize;
  ULONG BaseAddresses[PCI_TYPE0_ADDRESSES];
  PCI_EXPRESS_SRIOV_MIGRATION_STATE_ARRAY VFMigrationStateArrayOffset;
} PCI_EXPRESS_SRIOV_CAPABILITY, *PPCI_EXPRESS_SRIOV_CAPABILITY;

/* PCI device classes */
#define PCI_CLASS_PRE_20                    0x00
#define PCI_CLASS_MASS_STORAGE_CTLR         0x01
#define PCI_CLASS_NETWORK_CTLR              0x02
#define PCI_CLASS_DISPLAY_CTLR              0x03
#define PCI_CLASS_MULTIMEDIA_DEV            0x04
#define PCI_CLASS_MEMORY_CTLR               0x05
#define PCI_CLASS_BRIDGE_DEV                0x06
#define PCI_CLASS_SIMPLE_COMMS_CTLR         0x07
#define PCI_CLASS_BASE_SYSTEM_DEV           0x08
#define PCI_CLASS_INPUT_DEV                 0x09
#define PCI_CLASS_DOCKING_STATION           0x0a
#define PCI_CLASS_PROCESSOR                 0x0b
#define PCI_CLASS_SERIAL_BUS_CTLR           0x0c
#define PCI_CLASS_WIRELESS_CTLR             0x0d
#define PCI_CLASS_INTELLIGENT_IO_CTLR       0x0e
#define PCI_CLASS_SATELLITE_COMMS_CTLR      0x0f
#define PCI_CLASS_ENCRYPTION_DECRYPTION     0x10
#define PCI_CLASS_DATA_ACQ_SIGNAL_PROC      0x11
#define PCI_CLASS_NOT_DEFINED               0xff

/* PCI device subclasses for class 0 */
#define PCI_SUBCLASS_PRE_20_NON_VGA         0x00
#define PCI_SUBCLASS_PRE_20_VGA             0x01

/* PCI device subclasses for class 1 (mass storage controllers)*/
#define PCI_SUBCLASS_MSC_SCSI_BUS_CTLR      0x00
#define PCI_SUBCLASS_MSC_IDE_CTLR           0x01
#define PCI_SUBCLASS_MSC_FLOPPY_CTLR        0x02
#define PCI_SUBCLASS_MSC_IPI_CTLR           0x03
#define PCI_SUBCLASS_MSC_RAID_CTLR          0x04
#define PCI_SUBCLASS_MSC_OTHER              0x80

/* PCI device subclasses for class 2 (network controllers)*/
#define PCI_SUBCLASS_NET_ETHERNET_CTLR      0x00
#define PCI_SUBCLASS_NET_TOKEN_RING_CTLR    0x01
#define PCI_SUBCLASS_NET_FDDI_CTLR          0x02
#define PCI_SUBCLASS_NET_ATM_CTLR           0x03
#define PCI_SUBCLASS_NET_ISDN_CTLR          0x04
#define PCI_SUBCLASS_NET_OTHER              0x80

/* PCI device subclasses for class 3 (display controllers)*/
#define PCI_SUBCLASS_VID_VGA_CTLR           0x00
#define PCI_SUBCLASS_VID_XGA_CTLR           0x01
#define PCI_SUBCLASS_VID_3D_CTLR            0x02
#define PCI_SUBCLASS_VID_OTHER              0x80

/* PCI device subclasses for class 4 (multimedia device)*/
#define PCI_SUBCLASS_MM_VIDEO_DEV           0x00
#define PCI_SUBCLASS_MM_AUDIO_DEV           0x01
#define PCI_SUBCLASS_MM_TELEPHONY_DEV       0x02
#define PCI_SUBCLASS_MM_OTHER               0x80

/* PCI device subclasses for class 5 (memory controller)*/
#define PCI_SUBCLASS_MEM_RAM                0x00
#define PCI_SUBCLASS_MEM_FLASH              0x01
#define PCI_SUBCLASS_MEM_OTHER              0x80

/* PCI device subclasses for class 6 (bridge device)*/
#define PCI_SUBCLASS_BR_HOST                0x00
#define PCI_SUBCLASS_BR_ISA                 0x01
#define PCI_SUBCLASS_BR_EISA                0x02
#define PCI_SUBCLASS_BR_MCA                 0x03
#define PCI_SUBCLASS_BR_PCI_TO_PCI          0x04
#define PCI_SUBCLASS_BR_PCMCIA              0x05
#define PCI_SUBCLASS_BR_NUBUS               0x06
#define PCI_SUBCLASS_BR_CARDBUS             0x07
#define PCI_SUBCLASS_BR_RACEWAY             0x08
#define PCI_SUBCLASS_BR_OTHER               0x80

#define PCI_SUBCLASS_COM_SERIAL             0x00
#define PCI_SUBCLASS_COM_PARALLEL           0x01
#define PCI_SUBCLASS_COM_MULTIPORT          0x02
#define PCI_SUBCLASS_COM_MODEM              0x03
#define PCI_SUBCLASS_COM_OTHER              0x80

#define PCI_SUBCLASS_SYS_INTERRUPT_CTLR     0x00
#define PCI_SUBCLASS_SYS_DMA_CTLR           0x01
#define PCI_SUBCLASS_SYS_SYSTEM_TIMER       0x02
#define PCI_SUBCLASS_SYS_REAL_TIME_CLOCK    0x03
#define PCI_SUBCLASS_SYS_GEN_HOTPLUG_CTLR   0x04
#define PCI_SUBCLASS_SYS_SDIO_CTRL          0x05
#define PCI_SUBCLASS_SYS_OTHER              0x80

#define PCI_SUBCLASS_INP_KEYBOARD           0x00
#define PCI_SUBCLASS_INP_DIGITIZER          0x01
#define PCI_SUBCLASS_INP_MOUSE              0x02
#define PCI_SUBCLASS_INP_SCANNER            0x03
#define PCI_SUBCLASS_INP_GAMEPORT           0x04
#define PCI_SUBCLASS_INP_OTHER              0x80

#define PCI_SUBCLASS_DOC_GENERIC            0x00
#define PCI_SUBCLASS_DOC_OTHER              0x80

#define PCI_SUBCLASS_PROC_386               0x00
#define PCI_SUBCLASS_PROC_486               0x01
#define PCI_SUBCLASS_PROC_PENTIUM           0x02
#define PCI_SUBCLASS_PROC_ALPHA             0x10
#define PCI_SUBCLASS_PROC_POWERPC           0x20
#define PCI_SUBCLASS_PROC_COPROCESSOR       0x40

/* PCI device subclasses for class C (serial bus controller)*/
#define PCI_SUBCLASS_SB_IEEE1394            0x00
#define PCI_SUBCLASS_SB_ACCESS              0x01
#define PCI_SUBCLASS_SB_SSA                 0x02
#define PCI_SUBCLASS_SB_USB                 0x03
#define PCI_SUBCLASS_SB_FIBRE_CHANNEL       0x04
#define PCI_SUBCLASS_SB_SMBUS               0x05

#define PCI_SUBCLASS_WIRELESS_IRDA          0x00
#define PCI_SUBCLASS_WIRELESS_CON_IR        0x01
#define PCI_SUBCLASS_WIRELESS_RF            0x10
#define PCI_SUBCLASS_WIRELESS_OTHER         0x80

#define PCI_SUBCLASS_INTIO_I2O              0x00

#define PCI_SUBCLASS_SAT_TV                 0x01
#define PCI_SUBCLASS_SAT_AUDIO              0x02
#define PCI_SUBCLASS_SAT_VOICE              0x03
#define PCI_SUBCLASS_SAT_DATA               0x04

#define PCI_SUBCLASS_CRYPTO_NET_COMP        0x00
#define PCI_SUBCLASS_CRYPTO_ENTERTAINMENT   0x10
#define PCI_SUBCLASS_CRYPTO_OTHER           0x80

#define PCI_SUBCLASS_DASP_DPIO              0x00
#define PCI_SUBCLASS_DASP_OTHER             0x80

#define PCI_ADDRESS_IO_SPACE                0x00000001
#define PCI_ADDRESS_MEMORY_TYPE_MASK        0x00000006
#define PCI_ADDRESS_MEMORY_PREFETCHABLE     0x00000008
#define PCI_ADDRESS_IO_ADDRESS_MASK         0xfffffffc
#define PCI_ADDRESS_MEMORY_ADDRESS_MASK     0xfffffff0
#define PCI_ADDRESS_ROM_ADDRESS_MASK        0xfffff800

#define PCI_TYPE_32BIT                      0
#define PCI_TYPE_20BIT                      2
#define PCI_TYPE_64BIT                      4

#define PCI_ROMADDRESS_ENABLED              0x00000001

#endif /* _PCI_X_ */

#define PCI_EXPRESS_LINK_QUIESCENT_INTERFACE_VERSION       1

typedef NTSTATUS
(NTAPI PCI_EXPRESS_ENTER_LINK_QUIESCENT_MODE)(
  IN OUT PVOID Context);
typedef PCI_EXPRESS_ENTER_LINK_QUIESCENT_MODE *PPCI_EXPRESS_ENTER_LINK_QUIESCENT_MODE;

typedef NTSTATUS
(NTAPI PCI_EXPRESS_EXIT_LINK_QUIESCENT_MODE)(
  IN OUT PVOID Context);
typedef PCI_EXPRESS_EXIT_LINK_QUIESCENT_MODE *PPCI_EXPRESS_EXIT_LINK_QUIESCENT_MODE;

typedef struct _PCI_EXPRESS_LINK_QUIESCENT_INTERFACE {
  USHORT Size;
  USHORT Version;
  PVOID Context;
  PINTERFACE_REFERENCE InterfaceReference;
  PINTERFACE_DEREFERENCE InterfaceDereference;
  PPCI_EXPRESS_ENTER_LINK_QUIESCENT_MODE PciExpressEnterLinkQuiescentMode;
  PPCI_EXPRESS_EXIT_LINK_QUIESCENT_MODE PciExpressExitLinkQuiescentMode;
} PCI_EXPRESS_LINK_QUIESCENT_INTERFACE, *PPCI_EXPRESS_LINK_QUIESCENT_INTERFACE;

#define PCI_EXPRESS_ROOT_PORT_INTERFACE_VERSION            1

typedef ULONG
(NTAPI *PPCI_EXPRESS_ROOT_PORT_READ_CONFIG_SPACE)(
  IN PVOID Context,
  OUT PVOID Buffer,
  IN ULONG Offset,
  IN ULONG Length);

typedef ULONG
(NTAPI *PPCI_EXPRESS_ROOT_PORT_WRITE_CONFIG_SPACE)(
  IN PVOID Context,
  IN PVOID Buffer,
  IN ULONG Offset,
  IN ULONG Length);

typedef struct _PCI_EXPRESS_ROOT_PORT_INTERFACE {
  USHORT Size;
  USHORT Version;
  PVOID Context;
  PINTERFACE_REFERENCE InterfaceReference;
  PINTERFACE_DEREFERENCE InterfaceDereference;
  PPCI_EXPRESS_ROOT_PORT_READ_CONFIG_SPACE ReadConfigSpace;
  PPCI_EXPRESS_ROOT_PORT_WRITE_CONFIG_SPACE WriteConfigSpace;
} PCI_EXPRESS_ROOT_PORT_INTERFACE, *PPCI_EXPRESS_ROOT_PORT_INTERFACE;

#define PCI_MSIX_TABLE_CONFIG_INTERFACE_VERSION            1

typedef NTSTATUS
(NTAPI PCI_MSIX_SET_ENTRY)(
  IN PVOID Context,
  IN ULONG TableEntry,
  IN ULONG MessageNumber);
typedef PCI_MSIX_SET_ENTRY *PPCI_MSIX_SET_ENTRY;

typedef NTSTATUS
(NTAPI PCI_MSIX_MASKUNMASK_ENTRY)(
  IN PVOID Context,
  IN ULONG TableEntry);
typedef PCI_MSIX_MASKUNMASK_ENTRY *PPCI_MSIX_MASKUNMASK_ENTRY;

typedef NTSTATUS
(NTAPI PCI_MSIX_GET_ENTRY)(
  IN PVOID Context,
  IN ULONG TableEntry,
  OUT PULONG MessageNumber,
  OUT PBOOLEAN Masked);
typedef PCI_MSIX_GET_ENTRY *PPCI_MSIX_GET_ENTRY;

typedef NTSTATUS
(NTAPI PCI_MSIX_GET_TABLE_SIZE)(
  IN PVOID Context,
  OUT PULONG TableSize);
typedef PCI_MSIX_GET_TABLE_SIZE *PPCI_MSIX_GET_TABLE_SIZE;

typedef struct _PCI_MSIX_TABLE_CONFIG_INTERFACE {
  USHORT Size;
  USHORT Version;
  PVOID Context;
  PINTERFACE_REFERENCE InterfaceReference;
  PINTERFACE_DEREFERENCE InterfaceDereference;
  PPCI_MSIX_SET_ENTRY SetTableEntry;
  PPCI_MSIX_MASKUNMASK_ENTRY MaskTableEntry;
  PPCI_MSIX_MASKUNMASK_ENTRY UnmaskTableEntry;
  PPCI_MSIX_GET_ENTRY GetTableEntry;
  PPCI_MSIX_GET_TABLE_SIZE GetTableSize;
} PCI_MSIX_TABLE_CONFIG_INTERFACE, *PPCI_MSIX_TABLE_CONFIG_INTERFACE;

#define PCI_MSIX_TABLE_CONFIG_MINIMUM_SIZE \
        RTL_SIZEOF_THROUGH_FIELD(PCI_MSIX_TABLE_CONFIG_INTERFACE, UnmaskTableEntry)

/******************************************************************************
 *                            Object Manager Types                            *
 ******************************************************************************/

#define MAXIMUM_FILENAME_LENGTH           256
#define OBJ_NAME_PATH_SEPARATOR           ((WCHAR)L'\\')

#define OBJECT_TYPE_CREATE                0x0001
#define OBJECT_TYPE_ALL_ACCESS            (STANDARD_RIGHTS_REQUIRED | 0x1)

#define DIRECTORY_QUERY                   0x0001
#define DIRECTORY_TRAVERSE                0x0002
#define DIRECTORY_CREATE_OBJECT           0x0004
#define DIRECTORY_CREATE_SUBDIRECTORY     0x0008
#define DIRECTORY_ALL_ACCESS              (STANDARD_RIGHTS_REQUIRED | 0xF)

#define SYMBOLIC_LINK_QUERY               0x0001
#define SYMBOLIC_LINK_ALL_ACCESS          (STANDARD_RIGHTS_REQUIRED | 0x1)

#define DUPLICATE_CLOSE_SOURCE            0x00000001
#define DUPLICATE_SAME_ACCESS             0x00000002
#define DUPLICATE_SAME_ATTRIBUTES         0x00000004

#define OB_FLT_REGISTRATION_VERSION_0100  0x0100
#define OB_FLT_REGISTRATION_VERSION       OB_FLT_REGISTRATION_VERSION_0100

typedef ULONG OB_OPERATION;

#define OB_OPERATION_HANDLE_CREATE        0x00000001
#define OB_OPERATION_HANDLE_DUPLICATE     0x00000002

typedef struct _OB_PRE_CREATE_HANDLE_INFORMATION {
  IN OUT ACCESS_MASK DesiredAccess;
  IN ACCESS_MASK OriginalDesiredAccess;
} OB_PRE_CREATE_HANDLE_INFORMATION, *POB_PRE_CREATE_HANDLE_INFORMATION;

typedef struct _OB_PRE_DUPLICATE_HANDLE_INFORMATION {
  IN OUT ACCESS_MASK DesiredAccess;
  IN ACCESS_MASK OriginalDesiredAccess;
  IN PVOID SourceProcess;
  IN PVOID TargetProcess;
} OB_PRE_DUPLICATE_HANDLE_INFORMATION, *POB_PRE_DUPLICATE_HANDLE_INFORMATION;

typedef union _OB_PRE_OPERATION_PARAMETERS {
  IN OUT OB_PRE_CREATE_HANDLE_INFORMATION CreateHandleInformation;
  IN OUT OB_PRE_DUPLICATE_HANDLE_INFORMATION DuplicateHandleInformation;
} OB_PRE_OPERATION_PARAMETERS, *POB_PRE_OPERATION_PARAMETERS;

typedef struct _OB_PRE_OPERATION_INFORMATION {
  IN OB_OPERATION Operation;
  _ANONYMOUS_UNION union {
    IN ULONG Flags;
    _ANONYMOUS_STRUCT struct {
      IN ULONG KernelHandle:1;
      IN ULONG Reserved:31;
    } DUMMYSTRUCTNAME;
  } DUMMYUNIONNAME;
  IN PVOID Object;
  IN POBJECT_TYPE ObjectType;
  OUT PVOID CallContext;
  IN POB_PRE_OPERATION_PARAMETERS Parameters;
} OB_PRE_OPERATION_INFORMATION, *POB_PRE_OPERATION_INFORMATION;

typedef struct _OB_POST_CREATE_HANDLE_INFORMATION {
  IN ACCESS_MASK GrantedAccess;
} OB_POST_CREATE_HANDLE_INFORMATION, *POB_POST_CREATE_HANDLE_INFORMATION;

typedef struct _OB_POST_DUPLICATE_HANDLE_INFORMATION {
  IN ACCESS_MASK GrantedAccess;
} OB_POST_DUPLICATE_HANDLE_INFORMATION, *POB_POST_DUPLICATE_HANDLE_INFORMATION;

typedef union _OB_POST_OPERATION_PARAMETERS {
  IN OB_POST_CREATE_HANDLE_INFORMATION CreateHandleInformation;
  IN OB_POST_DUPLICATE_HANDLE_INFORMATION DuplicateHandleInformation;
} OB_POST_OPERATION_PARAMETERS, *POB_POST_OPERATION_PARAMETERS;

typedef struct _OB_POST_OPERATION_INFORMATION {
  IN OB_OPERATION Operation;
  _ANONYMOUS_UNION union {
    IN ULONG Flags;
    _ANONYMOUS_STRUCT struct {
      IN ULONG KernelHandle:1;
      IN ULONG Reserved:31;
    } DUMMYSTRUCTNAME;
  } DUMMYUNIONNAME;
  IN PVOID Object;
  IN POBJECT_TYPE ObjectType;
  IN PVOID CallContext;
  IN NTSTATUS ReturnStatus;
  IN POB_POST_OPERATION_PARAMETERS Parameters;
} OB_POST_OPERATION_INFORMATION,*POB_POST_OPERATION_INFORMATION;

typedef enum _OB_PREOP_CALLBACK_STATUS {
  OB_PREOP_SUCCESS
} OB_PREOP_CALLBACK_STATUS, *POB_PREOP_CALLBACK_STATUS;

typedef OB_PREOP_CALLBACK_STATUS
(NTAPI *POB_PRE_OPERATION_CALLBACK)(
  IN PVOID RegistrationContext,
  IN OUT POB_PRE_OPERATION_INFORMATION OperationInformation);

typedef VOID
(NTAPI *POB_POST_OPERATION_CALLBACK)(
  IN PVOID RegistrationContext,
  IN POB_POST_OPERATION_INFORMATION OperationInformation);

typedef struct _OB_OPERATION_REGISTRATION {
  IN POBJECT_TYPE *ObjectType;
  IN OB_OPERATION Operations;
  IN POB_PRE_OPERATION_CALLBACK PreOperation;
  IN POB_POST_OPERATION_CALLBACK PostOperation;
} OB_OPERATION_REGISTRATION, *POB_OPERATION_REGISTRATION;

typedef struct _OB_CALLBACK_REGISTRATION {
  IN USHORT Version;
  IN USHORT OperationRegistrationCount;
  IN UNICODE_STRING Altitude;
  IN PVOID RegistrationContext;
  IN OB_OPERATION_REGISTRATION *OperationRegistration;
} OB_CALLBACK_REGISTRATION, *POB_CALLBACK_REGISTRATION;

typedef struct _OBJECT_NAME_INFORMATION {
  UNICODE_STRING Name;
} OBJECT_NAME_INFORMATION, *POBJECT_NAME_INFORMATION;

/* Exported object types */
extern POBJECT_TYPE NTSYSAPI *CmKeyObjectType;
extern POBJECT_TYPE NTSYSAPI *ExEventObjectType;
extern POBJECT_TYPE NTSYSAPI *ExSemaphoreObjectType;
extern POBJECT_TYPE NTSYSAPI *IoFileObjectType;
extern POBJECT_TYPE NTSYSAPI *PsThreadType;
extern POBJECT_TYPE NTSYSAPI *SeTokenObjectType;
extern POBJECT_TYPE NTSYSAPI *PsProcessType;
extern POBJECT_TYPE NTSYSAPI *TmEnlistmentObjectType;
extern POBJECT_TYPE NTSYSAPI *TmResourceManagerObjectType;
extern POBJECT_TYPE NTSYSAPI *TmTransactionManagerObjectType;
extern POBJECT_TYPE NTSYSAPI *TmTransactionObjectType;

/******************************************************************************
 *                           Process Manager Types                            *
 ******************************************************************************/

#define QUOTA_LIMITS_HARDWS_MIN_ENABLE  0x00000001
#define QUOTA_LIMITS_HARDWS_MIN_DISABLE 0x00000002
#define QUOTA_LIMITS_HARDWS_MAX_ENABLE  0x00000004
#define QUOTA_LIMITS_HARDWS_MAX_DISABLE 0x00000008
#define QUOTA_LIMITS_USE_DEFAULT_LIMITS 0x00000010

/* Thread Access Rights */
#define THREAD_TERMINATE                 0x0001
#define THREAD_SUSPEND_RESUME            0x0002
#define THREAD_ALERT                     0x0004
#define THREAD_GET_CONTEXT               0x0008
#define THREAD_SET_CONTEXT               0x0010
#define THREAD_SET_INFORMATION           0x0020
#define THREAD_SET_LIMITED_INFORMATION   0x0400
#define THREAD_QUERY_LIMITED_INFORMATION 0x0800

#define PROCESS_DUP_HANDLE               (0x0040)

#if (NTDDI_VERSION >= NTDDI_VISTA)
#define PROCESS_ALL_ACCESS  (STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0xFFFF)
#else
#define PROCESS_ALL_ACCESS  (STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0xFFF)
#endif

#if (NTDDI_VERSION >= NTDDI_VISTA)
#define THREAD_ALL_ACCESS   (STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0xFFFF)
#else
#define THREAD_ALL_ACCESS   (STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0x3FF)
#endif

#define LOW_PRIORITY                      0
#define LOW_REALTIME_PRIORITY             16
#define HIGH_PRIORITY                     31
#define MAXIMUM_PRIORITY                  32


/******************************************************************************
 *                          WMI Library Support Types                         *
 ******************************************************************************/

#ifdef RUN_WPP
#include <evntrace.h>
#include <stdarg.h>
#endif

#ifndef _TRACEHANDLE_DEFINED
#define _TRACEHANDLE_DEFINED
typedef ULONG64 TRACEHANDLE, *PTRACEHANDLE;
#endif

#ifndef TRACE_INFORMATION_CLASS_DEFINE

typedef struct _ETW_TRACE_SESSION_SETTINGS {
  ULONG Version;
  ULONG BufferSize;
  ULONG MinimumBuffers;
  ULONG MaximumBuffers;
  ULONG LoggerMode;
  ULONG FlushTimer;
  ULONG FlushThreshold;
  ULONG ClockType;
} ETW_TRACE_SESSION_SETTINGS, *PETW_TRACE_SESSION_SETTINGS;

typedef enum _TRACE_INFORMATION_CLASS {
  TraceIdClass,
  TraceHandleClass,
  TraceEnableFlagsClass,
  TraceEnableLevelClass,
  GlobalLoggerHandleClass,
  EventLoggerHandleClass,
  AllLoggerHandlesClass,
  TraceHandleByNameClass,
  LoggerEventsLostClass,
  TraceSessionSettingsClass,
  LoggerEventsLoggedClass,
  MaxTraceInformationClass
} TRACE_INFORMATION_CLASS;

#endif /* TRACE_INFORMATION_CLASS_DEFINE */

#ifndef _ETW_KM_
#define _ETW_KM_
#endif

#include <evntprov.h>

typedef VOID
(NTAPI *PETWENABLECALLBACK)(
  IN LPCGUID SourceId,
  IN ULONG ControlCode,
  IN UCHAR Level,
  IN ULONGLONG MatchAnyKeyword,
  IN ULONGLONG MatchAllKeyword,
  IN PEVENT_FILTER_DESCRIPTOR FilterData OPTIONAL,
  IN OUT PVOID CallbackContext OPTIONAL);

#define EVENT_WRITE_FLAG_NO_FAULTING             0x00000001


#if defined(_M_IX86)
/** Kernel definitions for x86 **/

/* Interrupt request levels */
#define PASSIVE_LEVEL           0
#define LOW_LEVEL               0
#define APC_LEVEL               1
#define DISPATCH_LEVEL          2
#define CMCI_LEVEL              5
#define PROFILE_LEVEL           27
#define CLOCK1_LEVEL            28
#define CLOCK2_LEVEL            28
#define IPI_LEVEL               29
#define POWER_LEVEL             30
#define HIGH_LEVEL              31
#define CLOCK_LEVEL             CLOCK2_LEVEL

#define KIP0PCRADDRESS          0xffdff000
#define KI_USER_SHARED_DATA     0xffdf0000
#define SharedUserData          ((KUSER_SHARED_DATA * CONST)KI_USER_SHARED_DATA)

#define PAGE_SIZE               0x1000
#define PAGE_SHIFT              12L
#define KeGetDcacheFillSize()   1L

#define EFLAG_SIGN              0x8000
#define EFLAG_ZERO              0x4000
#define EFLAG_SELECT            (EFLAG_SIGN | EFLAG_ZERO)

#define RESULT_NEGATIVE         ((EFLAG_SIGN & ~EFLAG_ZERO) & EFLAG_SELECT)
#define RESULT_ZERO             ((~EFLAG_SIGN & EFLAG_ZERO) & EFLAG_SELECT)
#define RESULT_POSITIVE         ((~EFLAG_SIGN & ~EFLAG_ZERO) & EFLAG_SELECT)


typedef struct _KFLOATING_SAVE {
  ULONG ControlWord;
  ULONG StatusWord;
  ULONG ErrorOffset;
  ULONG ErrorSelector;
  ULONG DataOffset;
  ULONG DataSelector;
  ULONG Cr0NpxState;
  ULONG Spare1;
} KFLOATING_SAVE, *PKFLOATING_SAVE;

extern NTKERNELAPI volatile KSYSTEM_TIME KeTickCount;

#define YieldProcessor _mm_pause

FORCEINLINE
VOID
KeMemoryBarrier(VOID)
{
  volatile LONG Barrier;
#if defined(__GNUC__)
  __asm__ __volatile__ ("xchg %%eax, %0" : : "m" (Barrier) : "%eax");
#elif defined(_MSC_VER)
  __asm xchg [Barrier], eax
#endif
}

NTHALAPI
KIRQL
NTAPI
KeGetCurrentIrql(VOID);

NTHALAPI
VOID
FASTCALL
KfLowerIrql(
  IN KIRQL NewIrql);
#define KeLowerIrql(a) KfLowerIrql(a)

NTHALAPI
KIRQL
FASTCALL
KfRaiseIrql(
  IN KIRQL NewIrql);
#define KeRaiseIrql(a,b) *(b) = KfRaiseIrql(a)

NTHALAPI
KIRQL
NTAPI
KeRaiseIrqlToDpcLevel(VOID);

NTHALAPI
KIRQL
NTAPI
KeRaiseIrqlToSynchLevel(VOID);

NTHALAPI
KIRQL
FASTCALL
KfAcquireSpinLock(
  IN OUT PKSPIN_LOCK SpinLock);
#define KeAcquireSpinLock(a,b) *(b) = KfAcquireSpinLock(a)

NTHALAPI
VOID
FASTCALL
KfReleaseSpinLock(
  IN OUT PKSPIN_LOCK SpinLock,
  IN KIRQL NewIrql);
#define KeReleaseSpinLock(a,b) KfReleaseSpinLock(a,b)

NTKERNELAPI
VOID
FASTCALL
KefAcquireSpinLockAtDpcLevel(
  IN OUT PKSPIN_LOCK SpinLock);
#define KeAcquireSpinLockAtDpcLevel(SpinLock) KefAcquireSpinLockAtDpcLevel(SpinLock)

NTKERNELAPI
VOID
FASTCALL
KefReleaseSpinLockFromDpcLevel(
  IN OUT PKSPIN_LOCK SpinLock);
#define KeReleaseSpinLockFromDpcLevel(SpinLock) KefReleaseSpinLockFromDpcLevel(SpinLock)

NTSYSAPI
PKTHREAD
NTAPI
KeGetCurrentThread(VOID);

NTKERNELAPI
NTSTATUS
NTAPI
KeSaveFloatingPointState(
  OUT PKFLOATING_SAVE FloatSave);

NTKERNELAPI
NTSTATUS
NTAPI
KeRestoreFloatingPointState(
  IN PKFLOATING_SAVE FloatSave);

/* VOID
 * KeFlushIoBuffers(
 *   IN PMDL Mdl,
 *   IN BOOLEAN ReadOperation,
 *   IN BOOLEAN DmaOperation)
 */
#define KeFlushIoBuffers(_Mdl, _ReadOperation, _DmaOperation)

/* x86 and x64 performs a 0x2C interrupt */
#define DbgRaiseAssertionFailure __int2c

FORCEINLINE
VOID
_KeQueryTickCount(
  OUT PLARGE_INTEGER CurrentCount)
{
  for (;;) {
#ifdef NONAMELESSUNION
    CurrentCount->s.HighPart = KeTickCount.High1Time;
    CurrentCount->s.LowPart = KeTickCount.LowPart;
    if (CurrentCount->s.HighPart == KeTickCount.High2Time) break;
#else
    CurrentCount->HighPart = KeTickCount.High1Time;
    CurrentCount->LowPart = KeTickCount.LowPart;
    if (CurrentCount->HighPart == KeTickCount.High2Time) break;
#endif
    YieldProcessor();
  }
}
#define KeQueryTickCount(CurrentCount) _KeQueryTickCount(CurrentCount)


#elif defined(_M_AMD64)
/** Kernel definitions for AMD64 **/

/* Interrupt request levels */
#define PASSIVE_LEVEL           0
#define LOW_LEVEL               0
#define APC_LEVEL               1
#define DISPATCH_LEVEL          2
#define CMCI_LEVEL              5
#define CLOCK_LEVEL             13
#define IPI_LEVEL               14
#define DRS_LEVEL               14
#define POWER_LEVEL             14
#define PROFILE_LEVEL           15
#define HIGH_LEVEL              15

#define KI_USER_SHARED_DATA     0xFFFFF78000000000ULL
#define SharedUserData          ((PKUSER_SHARED_DATA const)KI_USER_SHARED_DATA)
#define SharedInterruptTime     (KI_USER_SHARED_DATA + 0x8)
#define SharedSystemTime        (KI_USER_SHARED_DATA + 0x14)
#define SharedTickCount         (KI_USER_SHARED_DATA + 0x320)

#define PAGE_SIZE               0x1000
#define PAGE_SHIFT              12L

#define EFLAG_SIGN              0x8000
#define EFLAG_ZERO              0x4000
#define EFLAG_SELECT            (EFLAG_SIGN | EFLAG_ZERO)

typedef struct _KFLOATING_SAVE {
  ULONG Dummy;
} KFLOATING_SAVE, *PKFLOATING_SAVE;

typedef XSAVE_FORMAT XMM_SAVE_AREA32, *PXMM_SAVE_AREA32;

#define KeQueryInterruptTime() \
    (*(volatile ULONG64*)SharedInterruptTime)

#define KeQuerySystemTime(CurrentCount) \
    *(ULONG64*)(CurrentCount) = *(volatile ULONG64*)SharedSystemTime

#define KeQueryTickCount(CurrentCount) \
    *(ULONG64*)(CurrentCount) = *(volatile ULONG64*)SharedTickCount

#define KeGetDcacheFillSize() 1L

#define YieldProcessor _mm_pause

FORCEINLINE
KIRQL
KeGetCurrentIrql(VOID)
{
  return (KIRQL)__readcr8();
}

FORCEINLINE
VOID
KeLowerIrql(IN KIRQL NewIrql)
{
  //ASSERT(KeGetCurrentIrql() >= NewIrql);
  __writecr8(NewIrql);
}

FORCEINLINE
KIRQL
KfRaiseIrql(IN KIRQL NewIrql)
{
  KIRQL OldIrql;

  OldIrql = (KIRQL)__readcr8();
  //ASSERT(OldIrql <= NewIrql);
  __writecr8(NewIrql);
  return OldIrql;
}
#define KeRaiseIrql(a,b) *(b) = KfRaiseIrql(a)

FORCEINLINE
KIRQL
KeRaiseIrqlToDpcLevel(VOID)
{
  return KfRaiseIrql(DISPATCH_LEVEL);
}

FORCEINLINE
KIRQL
KeRaiseIrqlToSynchLevel(VOID)
{
  return KfRaiseIrql(12); // SYNCH_LEVEL = IPI_LEVEL - 2
}

FORCEINLINE
PKTHREAD
KeGetCurrentThread(VOID)
{
  return (struct _KTHREAD *)__readgsqword(0x188);
}

/* VOID
 * KeFlushIoBuffers(
 *   IN PMDL Mdl,
 *   IN BOOLEAN ReadOperation,
 *   IN BOOLEAN DmaOperation)
 */
#define KeFlushIoBuffers(_Mdl, _ReadOperation, _DmaOperation)

/* x86 and x64 performs a 0x2C interrupt */
#define DbgRaiseAssertionFailure __int2c

#elif defined(_M_IA64)
/** Kernel definitions for IA64 **/

/* Interrupt request levels */
#define PASSIVE_LEVEL           0
#define LOW_LEVEL               0
#define APC_LEVEL               1
#define DISPATCH_LEVEL          2
#define CMC_LEVEL               3
#define DEVICE_LEVEL_BASE       4
#define PC_LEVEL                12
#define IPI_LEVEL               14
#define DRS_LEVEL               14
#define CLOCK_LEVEL             13
#define POWER_LEVEL             15
#define PROFILE_LEVEL           15
#define HIGH_LEVEL              15

#define KI_USER_SHARED_DATA ((ULONG_PTR)(KADDRESS_BASE + 0xFFFE0000))
extern volatile LARGE_INTEGER KeTickCount;

#define PAUSE_PROCESSOR __yield();

FORCEINLINE
VOID
KeFlushWriteBuffer(VOID)
{
  __mf ();
  return;
}

NTSYSAPI
PKTHREAD
NTAPI
KeGetCurrentThread(VOID);


#elif defined(_M_PPC)

/* Interrupt request levels */
#define PASSIVE_LEVEL                      0
#define LOW_LEVEL                          0
#define APC_LEVEL                          1
#define DISPATCH_LEVEL                     2
#define PROFILE_LEVEL                     27
#define CLOCK1_LEVEL                      28
#define CLOCK2_LEVEL                      28
#define IPI_LEVEL                         29
#define POWER_LEVEL                       30
#define HIGH_LEVEL                        31

//
// Used to contain PFNs and PFN counts
//
typedef ULONG PFN_COUNT;
typedef ULONG PFN_NUMBER, *PPFN_NUMBER;
typedef LONG SPFN_NUMBER, *PSPFN_NUMBER;


typedef struct _KFLOATING_SAVE {
  ULONG Dummy;
} KFLOATING_SAVE, *PKFLOATING_SAVE;

typedef struct _KPCR_TIB {
  PVOID ExceptionList;         /* 00 */
  PVOID StackBase;             /* 04 */
  PVOID StackLimit;            /* 08 */
  PVOID SubSystemTib;          /* 0C */
  _ANONYMOUS_UNION union {
    PVOID FiberData;           /* 10 */
    ULONG Version;             /* 10 */
  } DUMMYUNIONNAME;
  PVOID ArbitraryUserPointer;  /* 14 */
  struct _KPCR_TIB *Self;       /* 18 */
} KPCR_TIB, *PKPCR_TIB;         /* 1C */

#define PCR_MINOR_VERSION 1
#define PCR_MAJOR_VERSION 1

typedef struct _KPCR {
  KPCR_TIB Tib;                /* 00 */
  struct _KPCR *Self;          /* 1C */
  struct _KPRCB *Prcb;         /* 20 */
  KIRQL Irql;                  /* 24 */
  ULONG IRR;                   /* 28 */
  ULONG IrrActive;             /* 2C */
  ULONG IDR;                   /* 30 */
  PVOID KdVersionBlock;        /* 34 */
  PUSHORT IDT;                 /* 38 */
  PUSHORT GDT;                 /* 3C */
  struct _KTSS *TSS;           /* 40 */
  USHORT MajorVersion;         /* 44 */
  USHORT MinorVersion;         /* 46 */
  KAFFINITY SetMember;         /* 48 */
  ULONG StallScaleFactor;      /* 4C */
  UCHAR SpareUnused;           /* 50 */
  UCHAR Number;                /* 51 */
} KPCR, *PKPCR;                /* 54 */

#define KeGetPcr()                      PCR

#define YieldProcessor() __asm__ __volatile__("nop");

FORCEINLINE
ULONG
NTAPI
KeGetCurrentProcessorNumber(VOID)
{
  ULONG Number;
  __asm__ __volatile__ (
    "lwz %0, %c1(12)\n"
    : "=r" (Number)
    : "i" (FIELD_OFFSET(KPCR, Number))
  );
  return Number;
}

NTHALAPI
VOID
FASTCALL
KfLowerIrql(
  IN KIRQL NewIrql);
#define KeLowerIrql(a) KfLowerIrql(a)

NTHALAPI
KIRQL
FASTCALL
KfRaiseIrql(
  IN KIRQL NewIrql);
#define KeRaiseIrql(a,b) *(b) = KfRaiseIrql(a)

NTHALAPI
KIRQL
NTAPI
KeRaiseIrqlToDpcLevel(VOID);

NTHALAPI
KIRQL
NTAPI
KeRaiseIrqlToSynchLevel(VOID);



#elif defined(_M_MIPS)
#error MIPS Headers are totally incorrect

//
// Used to contain PFNs and PFN counts
//
typedef ULONG PFN_COUNT;
typedef ULONG PFN_NUMBER, *PPFN_NUMBER;
typedef LONG SPFN_NUMBER, *PSPFN_NUMBER;

#define PASSIVE_LEVEL                      0
#define APC_LEVEL                          1
#define DISPATCH_LEVEL                     2
#define PROFILE_LEVEL                     27
#define IPI_LEVEL                         29
#define HIGH_LEVEL                        31

typedef struct _KPCR {
  struct _KPRCB *Prcb;         /* 20 */
  KIRQL Irql;                  /* 24 */
  ULONG IRR;                   /* 28 */
  ULONG IDR;                   /* 30 */
} KPCR, *PKPCR;

#define KeGetPcr()                      PCR

typedef struct _KFLOATING_SAVE {
} KFLOATING_SAVE, *PKFLOATING_SAVE;

static __inline
ULONG
NTAPI
KeGetCurrentProcessorNumber(VOID)
{
  return 0;
}

#define YieldProcessor() __asm__ __volatile__("nop");

#define KeLowerIrql(a) KfLowerIrql(a)
#define KeRaiseIrql(a,b) *(b) = KfRaiseIrql(a)

NTKERNELAPI
VOID
NTAPI
KfLowerIrql(
  IN KIRQL NewIrql);

NTKERNELAPI
KIRQL
NTAPI
KfRaiseIrql(
  IN KIRQL NewIrql);

NTKERNELAPI
KIRQL
NTAPI
KeRaiseIrqlToDpcLevel(VOID);

NTKERNELAPI
KIRQL
NTAPI
KeRaiseIrqlToSynchLevel(VOID);


#elif defined(_M_ARM)
#include <armddk.h>
#else
#error Unknown Architecture
#endif


/******************************************************************************
 *                         Runtime Library Functions                          *
 ******************************************************************************/

#if !defined(MIDL_PASS) && !defined(SORTPP_PASS)

#define RTL_STATIC_LIST_HEAD(x) LIST_ENTRY x = { &x, &x }

FORCEINLINE
VOID
InitializeListHead(
  OUT PLIST_ENTRY ListHead)
{
  ListHead->Flink = ListHead->Blink = ListHead;
}

FORCEINLINE
BOOLEAN
IsListEmpty(
  IN CONST LIST_ENTRY * ListHead)
{
  return (BOOLEAN)(ListHead->Flink == ListHead);
}

FORCEINLINE
BOOLEAN
RemoveEntryList(
  IN PLIST_ENTRY Entry)
{
  PLIST_ENTRY OldFlink;
  PLIST_ENTRY OldBlink;

  OldFlink = Entry->Flink;
  OldBlink = Entry->Blink;
  OldFlink->Blink = OldBlink;
  OldBlink->Flink = OldFlink;
  return (BOOLEAN)(OldFlink == OldBlink);
}

FORCEINLINE
PLIST_ENTRY
RemoveHeadList(
  IN OUT PLIST_ENTRY ListHead)
{
  PLIST_ENTRY Flink;
  PLIST_ENTRY Entry;

  Entry = ListHead->Flink;
  Flink = Entry->Flink;
  ListHead->Flink = Flink;
  Flink->Blink = ListHead;
  return Entry;
}

FORCEINLINE
PLIST_ENTRY
RemoveTailList(
  IN OUT PLIST_ENTRY ListHead)
{
  PLIST_ENTRY Blink;
  PLIST_ENTRY Entry;

  Entry = ListHead->Blink;
  Blink = Entry->Blink;
  ListHead->Blink = Blink;
  Blink->Flink = ListHead;
  return Entry;
}

FORCEINLINE
VOID
InsertTailList(
  IN OUT PLIST_ENTRY ListHead,
  IN OUT PLIST_ENTRY Entry)
{
  PLIST_ENTRY OldBlink;
  OldBlink = ListHead->Blink;
  Entry->Flink = ListHead;
  Entry->Blink = OldBlink;
  OldBlink->Flink = Entry;
  ListHead->Blink = Entry;
}

FORCEINLINE
VOID
InsertHeadList(
  IN OUT PLIST_ENTRY ListHead,
  IN OUT PLIST_ENTRY Entry)
{
  PLIST_ENTRY OldFlink;
  OldFlink = ListHead->Flink;
  Entry->Flink = OldFlink;
  Entry->Blink = ListHead;
  OldFlink->Blink = Entry;
  ListHead->Flink = Entry;
}

FORCEINLINE
VOID
AppendTailList(
  IN OUT PLIST_ENTRY ListHead,
  IN OUT PLIST_ENTRY ListToAppend)
{
  PLIST_ENTRY ListEnd = ListHead->Blink;

  ListHead->Blink->Flink = ListToAppend;
  ListHead->Blink = ListToAppend->Blink;
  ListToAppend->Blink->Flink = ListHead;
  ListToAppend->Blink = ListEnd;
}

FORCEINLINE
PSINGLE_LIST_ENTRY
PopEntryList(
  IN OUT PSINGLE_LIST_ENTRY ListHead)
{
  PSINGLE_LIST_ENTRY FirstEntry;
  FirstEntry = ListHead->Next;
  if (FirstEntry != NULL) {
    ListHead->Next = FirstEntry->Next;
  }
  return FirstEntry;
}

FORCEINLINE
VOID
PushEntryList(
  IN OUT PSINGLE_LIST_ENTRY ListHead,
  IN OUT PSINGLE_LIST_ENTRY Entry)
{
  Entry->Next = ListHead->Next;
  ListHead->Next = Entry;
}

#endif /* !defined(MIDL_PASS) && !defined(SORTPP_PASS) */

NTSYSAPI
VOID
NTAPI
RtlAssert(
  IN PVOID FailedAssertion,
  IN PVOID FileName,
  IN ULONG LineNumber,
  IN PSTR Message);

/* VOID
 * RtlCopyMemory(
 *     IN VOID UNALIGNED *Destination,
 *     IN CONST VOID UNALIGNED *Source,
 *     IN SIZE_T Length)
 */
#define RtlCopyMemory(Destination, Source, Length) \
    memcpy(Destination, Source, Length)

#define RtlCopyBytes RtlCopyMemory

#if defined(_M_AMD64)
NTSYSAPI
VOID
NTAPI
RtlCopyMemoryNonTemporal(
  VOID UNALIGNED *Destination,
  CONST VOID UNALIGNED *Source,
  SIZE_T Length);
#else
#define RtlCopyMemoryNonTemporal RtlCopyMemory
#endif

/* BOOLEAN
 * RtlEqualLuid(
 *     IN PLUID Luid1,
 *     IN PLUID Luid2)
 */
#define RtlEqualLuid(Luid1, Luid2) \
    (((Luid1)->LowPart == (Luid2)->LowPart) && ((Luid1)->HighPart == (Luid2)->HighPart))

/* ULONG
 * RtlEqualMemory(
 *     IN VOID UNALIGNED *Destination,
 *     IN CONST VOID UNALIGNED *Source,
 *     IN SIZE_T Length)
 */
#define RtlEqualMemory(Destination, Source, Length) \
    (!memcmp(Destination, Source, Length))

/* VOID
 * RtlFillMemory(
 *     IN VOID UNALIGNED *Destination,
 *     IN SIZE_T Length,
 *     IN UCHAR Fill)
 */
#define RtlFillMemory(Destination, Length, Fill) \
    memset(Destination, Fill, Length)

#define RtlFillBytes RtlFillMemory

NTSYSAPI
VOID
NTAPI
RtlFreeUnicodeString(
  IN OUT PUNICODE_STRING UnicodeString);

NTSYSAPI
NTSTATUS
NTAPI
RtlGUIDFromString(
  IN PUNICODE_STRING GuidString,
  OUT GUID *Guid);

NTSYSAPI
VOID
NTAPI
RtlInitUnicodeString(
  IN OUT PUNICODE_STRING DestinationString,
  IN PCWSTR SourceString OPTIONAL);

/* VOID
 * RtlMoveMemory(
 *    IN VOID UNALIGNED *Destination,
 *    IN CONST VOID UNALIGNED *Source,
 *    IN SIZE_T Length)
 */
#define RtlMoveMemory(Destination, Source, Length) \
    memmove(Destination, Source, Length)

NTSYSAPI
NTSTATUS
NTAPI
RtlStringFromGUID(
  IN REFGUID Guid,
  OUT PUNICODE_STRING GuidString);

/* VOID
 * RtlZeroMemory(
 *     IN VOID UNALIGNED *Destination,
 *     IN SIZE_T Length)
 */
#define RtlZeroMemory(Destination, Length) \
    memset(Destination, 0, Length)

#define RtlZeroBytes RtlZeroMemory

#if (NTDDI_VERSION >= NTDDI_WIN2K)

NTSYSAPI
BOOLEAN
NTAPI
RtlAreBitsClear(
  IN PRTL_BITMAP BitMapHeader,
  IN ULONG StartingIndex,
  IN ULONG Length);

NTSYSAPI
BOOLEAN
NTAPI
RtlAreBitsSet(
  IN PRTL_BITMAP BitMapHeader,
  IN ULONG StartingIndex,
  IN ULONG Length);

NTSYSAPI
NTSTATUS
NTAPI
RtlAnsiStringToUnicodeString(
  IN OUT PUNICODE_STRING DestinationString,
  IN PANSI_STRING SourceString,
  IN BOOLEAN AllocateDestinationString);

NTSYSAPI
ULONG
NTAPI
RtlxAnsiStringToUnicodeSize(
  IN PCANSI_STRING AnsiString);

#define RtlAnsiStringToUnicodeSize(String) (               \
  NLS_MB_CODE_PAGE_TAG ?                                   \
  RtlxAnsiStringToUnicodeSize(String) :                    \
  ((String)->Length + sizeof(ANSI_NULL)) * sizeof(WCHAR)   \
)

NTSYSAPI
NTSTATUS
NTAPI
RtlAppendUnicodeStringToString(
  IN OUT PUNICODE_STRING Destination,
  IN PCUNICODE_STRING Source);

NTSYSAPI
NTSTATUS
NTAPI
RtlAppendUnicodeToString(
  IN OUT PUNICODE_STRING Destination,
  IN PCWSTR Source);

NTSYSAPI
NTSTATUS
NTAPI
RtlCheckRegistryKey(
  IN ULONG RelativeTo,
  IN PWSTR Path);

NTSYSAPI
VOID
NTAPI
RtlClearAllBits(
  IN PRTL_BITMAP BitMapHeader);

NTSYSAPI
VOID
NTAPI
RtlClearBits(
  IN PRTL_BITMAP BitMapHeader,
  IN ULONG StartingIndex,
  IN ULONG NumberToClear);

NTSYSAPI
SIZE_T
NTAPI
RtlCompareMemory(
  IN CONST VOID *Source1,
  IN CONST VOID *Source2,
  IN SIZE_T Length);

NTSYSAPI
LONG
NTAPI
RtlCompareUnicodeString(
  IN PCUNICODE_STRING String1,
  IN PCUNICODE_STRING String2,
  IN BOOLEAN CaseInSensitive);

NTSYSAPI
LONG
NTAPI
RtlCompareUnicodeStrings(
  IN PCWCH String1,
  IN SIZE_T String1Length,
  IN PCWCH String2,
  IN SIZE_T String2Length,
  IN BOOLEAN CaseInSensitive);

NTSYSAPI
VOID
NTAPI
RtlCopyUnicodeString(
  IN OUT PUNICODE_STRING DestinationString,
  IN PCUNICODE_STRING SourceString OPTIONAL);

NTSYSAPI
NTSTATUS
NTAPI
RtlCreateRegistryKey(
  IN ULONG RelativeTo,
  IN PWSTR Path);

NTSYSAPI
NTSTATUS
NTAPI
RtlCreateSecurityDescriptor(
  IN OUT PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN ULONG Revision);

NTSYSAPI
NTSTATUS
NTAPI
RtlDeleteRegistryValue(
  IN ULONG RelativeTo,
  IN PCWSTR Path,
  IN PCWSTR ValueName);

NTSYSAPI
BOOLEAN
NTAPI
RtlEqualUnicodeString(
  IN CONST UNICODE_STRING *String1,
  IN CONST UNICODE_STRING *String2,
  IN BOOLEAN CaseInSensitive);

#if !defined(_AMD64_) && !defined(_IA64_)
NTSYSAPI
LARGE_INTEGER
NTAPI
RtlExtendedIntegerMultiply(
  IN LARGE_INTEGER Multiplicand,
  IN LONG Multiplier);

NTSYSAPI
LARGE_INTEGER
NTAPI
RtlExtendedLargeIntegerDivide(
  IN LARGE_INTEGER Dividend,
  IN ULONG Divisor,
  OUT PULONG Remainder OPTIONAL);
#endif

#if defined(_X86_) || defined(_IA64_)
NTSYSAPI
LARGE_INTEGER
NTAPI
RtlExtendedMagicDivide(
    IN LARGE_INTEGER Dividend,
    IN LARGE_INTEGER MagicDivisor,
    IN CCHAR  ShiftCount);
#endif

NTSYSAPI
VOID
NTAPI
RtlFreeAnsiString(
  IN PANSI_STRING AnsiString);

NTSYSAPI
ULONG
NTAPI
RtlFindClearBits(
  IN PRTL_BITMAP BitMapHeader,
  IN ULONG NumberToFind,
  IN ULONG HintIndex);

NTSYSAPI
ULONG
NTAPI
RtlFindClearBitsAndSet(
  IN PRTL_BITMAP BitMapHeader,
  IN ULONG NumberToFind,
  IN ULONG HintIndex);

NTSYSAPI
ULONG
NTAPI
RtlFindFirstRunClear(
  IN PRTL_BITMAP BitMapHeader,
  OUT PULONG StartingIndex);

NTSYSAPI
ULONG
NTAPI
RtlFindClearRuns(
  IN PRTL_BITMAP BitMapHeader,
  OUT PRTL_BITMAP_RUN RunArray,
  IN ULONG SizeOfRunArray,
  IN BOOLEAN LocateLongestRuns);

NTSYSAPI
ULONG
NTAPI
RtlFindLastBackwardRunClear(
  IN PRTL_BITMAP BitMapHeader,
  IN ULONG FromIndex,
  OUT PULONG StartingRunIndex);

NTSYSAPI
CCHAR
NTAPI
RtlFindLeastSignificantBit(
  IN ULONGLONG Set);

NTSYSAPI
ULONG
NTAPI
RtlFindLongestRunClear(
  IN PRTL_BITMAP BitMapHeader,
  OUT PULONG StartingIndex);

NTSYSAPI
CCHAR
NTAPI
RtlFindMostSignificantBit(
  IN ULONGLONG Set);

NTSYSAPI
ULONG
NTAPI
RtlFindNextForwardRunClear(
  IN PRTL_BITMAP BitMapHeader,
  IN ULONG FromIndex,
  OUT PULONG StartingRunIndex);

NTSYSAPI
ULONG
NTAPI
RtlFindSetBits(
  IN PRTL_BITMAP BitMapHeader,
  IN ULONG NumberToFind,
  IN ULONG HintIndex);

NTSYSAPI
ULONG
NTAPI
RtlFindSetBitsAndClear(
  IN PRTL_BITMAP BitMapHeader,
  IN ULONG NumberToFind,
  IN ULONG HintIndex);

NTSYSAPI
VOID
NTAPI
RtlInitAnsiString(
  IN OUT PANSI_STRING DestinationString,
  IN PCSZ SourceString);

NTSYSAPI
VOID
NTAPI
RtlInitializeBitMap(
  IN PRTL_BITMAP BitMapHeader,
  IN PULONG BitMapBuffer,
  IN ULONG SizeOfBitMap);

NTSYSAPI
VOID
NTAPI
RtlInitString(
  IN OUT PSTRING DestinationString,
  IN PCSZ SourceString);

NTSYSAPI
NTSTATUS
NTAPI
RtlIntegerToUnicodeString(
  IN ULONG Value,
  IN ULONG Base OPTIONAL,
  IN OUT PUNICODE_STRING String);

NTSYSAPI
NTSTATUS
NTAPI
RtlInt64ToUnicodeString(
  IN ULONGLONG Value,
  IN ULONG Base OPTIONAL,
  IN OUT PUNICODE_STRING String);

#ifdef _WIN64
#define RtlIntPtrToUnicodeString(Value, Base, String) \
    RtlInt64ToUnicodeString(Value, Base, String)
#else
#define RtlIntPtrToUnicodeString(Value, Base, String) \
    RtlIntegerToUnicodeString(Value, Base, String)
#endif

/* BOOLEAN
 * RtlIsZeroLuid(
 *     IN PLUID L1);
 */
#define RtlIsZeroLuid(_L1) \
    ((BOOLEAN) ((!(_L1)->LowPart) && (!(_L1)->HighPart)))

NTSYSAPI
ULONG
NTAPI
RtlLengthSecurityDescriptor(
  IN PSECURITY_DESCRIPTOR SecurityDescriptor);

NTSYSAPI
ULONG
NTAPI
RtlNumberOfClearBits(
  IN PRTL_BITMAP BitMapHeader);

NTSYSAPI
ULONG
NTAPI
RtlNumberOfSetBits(
  IN PRTL_BITMAP BitMapHeader);

NTSYSAPI
NTSTATUS
NTAPI
RtlQueryRegistryValues(
  IN ULONG RelativeTo,
  IN PCWSTR Path,
  IN OUT PRTL_QUERY_REGISTRY_TABLE QueryTable,
  IN PVOID Context OPTIONAL,
  IN PVOID Environment OPTIONAL);

#define SHORT_SIZE  (sizeof(USHORT))
#define SHORT_MASK  (SHORT_SIZE - 1)
#define LONG_SIZE (sizeof(LONG))
#define LONGLONG_SIZE   (sizeof(LONGLONG))
#define LONG_MASK (LONG_SIZE - 1)
#define LONGLONG_MASK   (LONGLONG_SIZE - 1)
#define LOWBYTE_MASK 0x00FF

#define FIRSTBYTE(VALUE)  ((VALUE) & LOWBYTE_MASK)
#define SECONDBYTE(VALUE) (((VALUE) >> 8) & LOWBYTE_MASK)
#define THIRDBYTE(VALUE)  (((VALUE) >> 16) & LOWBYTE_MASK)
#define FOURTHBYTE(VALUE) (((VALUE) >> 24) & LOWBYTE_MASK)

NTSYSAPI
VOID
NTAPI
RtlSetAllBits(
  IN PRTL_BITMAP BitMapHeader);

NTSYSAPI
VOID
NTAPI
RtlSetBits(
  IN PRTL_BITMAP BitMapHeader,
  IN ULONG StartingIndex,
  IN ULONG NumberToSet);

NTSYSAPI
NTSTATUS
NTAPI
RtlSetDaclSecurityDescriptor(
  IN OUT PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN BOOLEAN DaclPresent,
  IN PACL Dacl OPTIONAL,
  IN BOOLEAN DaclDefaulted OPTIONAL);

#if defined(_AMD64_)

/* VOID
 * RtlStoreUlong(
 *     IN PULONG Address,
 *     IN ULONG Value);
 */
#define RtlStoreUlong(Address,Value) \
    *(ULONG UNALIGNED *)(Address) = (Value)

/* VOID
 * RtlStoreUlonglong(
 *     IN OUT PULONGLONG Address,
 *     ULONGLONG Value);
 */
#define RtlStoreUlonglong(Address,Value) \
    *(ULONGLONG UNALIGNED *)(Address) = (Value)

/* VOID
 * RtlStoreUshort(
 *     IN PUSHORT Address,
 *     IN USHORT Value);
 */
#define RtlStoreUshort(Address,Value) \
    *(USHORT UNALIGNED *)(Address) = (Value)

/* VOID
 * RtlRetrieveUshort(
 *     PUSHORT DestinationAddress,
 *    PUSHORT SourceAddress);
 */
#define RtlRetrieveUshort(DestAddress,SrcAddress) \
    *(USHORT UNALIGNED *)(DestAddress) = *(USHORT)(SrcAddress)

/* VOID
 * RtlRetrieveUlong(
 *    PULONG DestinationAddress,
 *    PULONG SourceAddress);
 */
#define RtlRetrieveUlong(DestAddress,SrcAddress) \
    *(ULONG UNALIGNED *)(DestAddress) = *(PULONG)(SrcAddress)

#else

#define RtlStoreUlong(Address,Value)                      \
    if ((ULONG_PTR)(Address) & LONG_MASK) { \
        ((PUCHAR) (Address))[LONG_LEAST_SIGNIFICANT_BIT]    = (UCHAR)(FIRSTBYTE(Value)); \
        ((PUCHAR) (Address))[LONG_3RD_MOST_SIGNIFICANT_BIT] = (UCHAR)(SECONDBYTE(Value)); \
        ((PUCHAR) (Address))[LONG_2ND_MOST_SIGNIFICANT_BIT] = (UCHAR)(THIRDBYTE(Value)); \
        ((PUCHAR) (Address))[LONG_MOST_SIGNIFICANT_BIT]     = (UCHAR)(FOURTHBYTE(Value)); \
    } \
    else { \
        *((PULONG)(Address)) = (ULONG) (Value); \
    }

#define RtlStoreUlonglong(Address,Value) \
    if ((ULONG_PTR)(Address) & LONGLONG_MASK) { \
        RtlStoreUlong((ULONG_PTR)(Address), \
                      (ULONGLONG)(Value) & 0xFFFFFFFF); \
        RtlStoreUlong((ULONG_PTR)(Address)+sizeof(ULONG), \
                      (ULONGLONG)(Value) >> 32); \
    } else { \
        *((PULONGLONG)(Address)) = (ULONGLONG)(Value); \
    }

#define RtlStoreUshort(Address,Value) \
    if ((ULONG_PTR)(Address) & SHORT_MASK) { \
        ((PUCHAR) (Address))[SHORT_LEAST_SIGNIFICANT_BIT] = (UCHAR)(FIRSTBYTE(Value)); \
        ((PUCHAR) (Address))[SHORT_MOST_SIGNIFICANT_BIT ] = (UCHAR)(SECONDBYTE(Value)); \
    } \
    else { \
        *((PUSHORT) (Address)) = (USHORT)Value; \
    }

#define RtlRetrieveUshort(DestAddress,SrcAddress) \
    if ((ULONG_PTR)(SrcAddress) & LONG_MASK) \
    { \
        ((PUCHAR)(DestAddress))[0]=((PUCHAR)(SrcAddress))[0]; \
        ((PUCHAR)(DestAddress))[1]=((PUCHAR)(SrcAddress))[1]; \
    } \
    else \
    { \
        *((PUSHORT)(DestAddress))=*((PUSHORT)(SrcAddress)); \
    }

#define RtlRetrieveUlong(DestAddress,SrcAddress) \
    if ((ULONG_PTR)(SrcAddress) & LONG_MASK) \
    { \
        ((PUCHAR)(DestAddress))[0]=((PUCHAR)(SrcAddress))[0]; \
        ((PUCHAR)(DestAddress))[1]=((PUCHAR)(SrcAddress))[1]; \
        ((PUCHAR)(DestAddress))[2]=((PUCHAR)(SrcAddress))[2]; \
        ((PUCHAR)(DestAddress))[3]=((PUCHAR)(SrcAddress))[3]; \
    } \
    else \
    { \
        *((PULONG)(DestAddress))=*((PULONG)(SrcAddress)); \
    }

#endif /* defined(_AMD64_) */

#ifdef _WIN64
/* VOID
 * RtlStoreUlongPtr(
 *     IN OUT PULONG_PTR Address,
 *     IN ULONG_PTR Value);
 */
#define RtlStoreUlongPtr(Address,Value) RtlStoreUlonglong(Address,Value)
#else
#define RtlStoreUlongPtr(Address,Value) RtlStoreUlong(Address,Value)
#endif /* _WIN64 */

NTSYSAPI
BOOLEAN
NTAPI
RtlTimeFieldsToTime(
  IN PTIME_FIELDS TimeFields,
  IN PLARGE_INTEGER Time);

NTSYSAPI
VOID
NTAPI
RtlTimeToTimeFields(
  IN PLARGE_INTEGER Time,
  IN PTIME_FIELDS TimeFields);

NTSYSAPI
ULONG
FASTCALL
RtlUlongByteSwap(
  IN ULONG Source);

NTSYSAPI
ULONGLONG
FASTCALL
RtlUlonglongByteSwap(
  IN ULONGLONG Source);

NTSYSAPI
NTSTATUS
NTAPI
RtlUnicodeStringToAnsiString(
  IN OUT PANSI_STRING DestinationString,
  IN PCUNICODE_STRING SourceString,
  IN BOOLEAN AllocateDestinationString);

NTSYSAPI
ULONG
NTAPI
RtlxUnicodeStringToAnsiSize(
  IN PCUNICODE_STRING UnicodeString);

#define RtlUnicodeStringToAnsiSize(String) (                  \
    NLS_MB_CODE_PAGE_TAG ?                                    \
    RtlxUnicodeStringToAnsiSize(String) :                     \
    ((String)->Length + sizeof(UNICODE_NULL)) / sizeof(WCHAR) \
)

NTSYSAPI
NTSTATUS
NTAPI
RtlUnicodeStringToInteger(
  IN PCUNICODE_STRING String,
  IN ULONG Base OPTIONAL,
  OUT PULONG Value);

NTSYSAPI
WCHAR
NTAPI
RtlUpcaseUnicodeChar(
  IN WCHAR SourceCharacter);

NTSYSAPI
USHORT
FASTCALL
RtlUshortByteSwap(
  IN USHORT Source);

NTSYSAPI
BOOLEAN
NTAPI
RtlValidRelativeSecurityDescriptor(
  IN PSECURITY_DESCRIPTOR SecurityDescriptorInput,
  IN ULONG SecurityDescriptorLength,
  IN SECURITY_INFORMATION RequiredInformation);

NTSYSAPI
BOOLEAN
NTAPI
RtlValidSecurityDescriptor(
  IN PSECURITY_DESCRIPTOR SecurityDescriptor);

NTSYSAPI
NTSTATUS
NTAPI
RtlWriteRegistryValue(
  IN ULONG RelativeTo,
  IN PCWSTR Path,
  IN PCWSTR ValueName,
  IN ULONG ValueType,
  IN PVOID ValueData,
  IN ULONG ValueLength);


#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */


#if (NTDDI_VERSION >= NTDDI_WIN2KSP3)
NTSYSAPI
VOID
FASTCALL
RtlPrefetchMemoryNonTemporal(
  IN PVOID Source,
  IN SIZE_T Length);
#endif


#if (NTDDI_VERSION >= NTDDI_WINXP)


NTSYSAPI
VOID
NTAPI
RtlClearBit(
  PRTL_BITMAP BitMapHeader,
  ULONG BitNumber);

NTSYSAPI
WCHAR
NTAPI
RtlDowncaseUnicodeChar(
  IN WCHAR SourceCharacter);

NTSYSAPI
VOID
NTAPI
RtlSetBit(
  PRTL_BITMAP BitMapHeader,
  ULONG BitNumber);

NTSYSAPI
BOOLEAN
NTAPI
RtlTestBit(
  IN PRTL_BITMAP BitMapHeader,
  IN ULONG BitNumber);

NTSYSAPI
NTSTATUS
NTAPI
RtlHashUnicodeString(
  IN CONST UNICODE_STRING *String,
  IN BOOLEAN CaseInSensitive,
  IN ULONG HashAlgorithm,
  OUT PULONG HashValue);

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */


#if (NTDDI_VERSION >= NTDDI_VISTA)

NTSYSAPI
ULONG
NTAPI
RtlNumberOfSetBitsUlongPtr(
  IN ULONG_PTR Target);

NTSYSAPI
ULONGLONG
NTAPI
RtlIoDecodeMemIoResource(
  IN struct _IO_RESOURCE_DESCRIPTOR *Descriptor,
  OUT PULONGLONG Alignment OPTIONAL,
  OUT PULONGLONG MinimumAddress OPTIONAL,
  OUT PULONGLONG MaximumAddress OPTIONAL);

NTSYSAPI
NTSTATUS
NTAPI
RtlIoEncodeMemIoResource(
  IN struct _IO_RESOURCE_DESCRIPTOR *Descriptor,
  IN UCHAR Type,
  IN ULONGLONG Length,
  IN ULONGLONG Alignment,
  IN ULONGLONG MinimumAddress,
  IN ULONGLONG MaximumAddress);

NTSYSAPI
ULONGLONG
NTAPI
RtlCmDecodeMemIoResource(
  IN struct _CM_PARTIAL_RESOURCE_DESCRIPTOR *Descriptor,
  OUT PULONGLONG Start OPTIONAL);

NTSYSAPI
NTSTATUS
NTAPI
RtlFindClosestEncodableLength(
  IN ULONGLONG SourceLength,
  OUT PULONGLONG TargetLength);

NTSYSAPI
NTSTATUS
NTAPI
RtlCmEncodeMemIoResource(
  IN PCM_PARTIAL_RESOURCE_DESCRIPTOR Descriptor,
  IN UCHAR Type,
  IN ULONGLONG Length,
  IN ULONGLONG Start);

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#if (NTDDI_VERSION >= NTDDI_WIN7)

NTSYSAPI
NTSTATUS
NTAPI
RtlUnicodeToUTF8N(
  OUT PCHAR UTF8StringDestination,
  IN ULONG UTF8StringMaxByteCount,
  OUT PULONG UTF8StringActualByteCount,
  IN PCWCH UnicodeStringSource,
  IN ULONG UnicodeStringByteCount);

NTSYSAPI
NTSTATUS
NTAPI
RtlUTF8ToUnicodeN(
  OUT PWSTR UnicodeStringDestination,
  IN ULONG UnicodeStringMaxByteCount,
  OUT PULONG UnicodeStringActualByteCount,
  IN PCCH UTF8StringSource,
  IN ULONG UTF8StringByteCount);

NTSYSAPI
ULONG64
NTAPI
RtlGetEnabledExtendedFeatures(
  IN ULONG64 FeatureMask);

#endif /* (NTDDI_VERSION >= NTDDI_WIN7) */


#if !defined(MIDL_PASS)
/* inline funftions */
//DECLSPEC_DEPRECATED_DDK_WINXP
static __inline
LARGE_INTEGER
NTAPI_INLINE
RtlConvertLongToLargeInteger(
  IN LONG SignedInteger)
{
  LARGE_INTEGER ret;
  ret.QuadPart = SignedInteger;
  return ret;
}

//DECLSPEC_DEPRECATED_DDK_WINXP
static __inline
LARGE_INTEGER
NTAPI_INLINE
RtlConvertUlongToLargeInteger(
  IN ULONG UnsignedInteger)
{
  LARGE_INTEGER ret;
  ret.QuadPart = UnsignedInteger;
  return ret;
}

//DECLSPEC_DEPRECATED_DDK_WINXP
static __inline
LARGE_INTEGER
NTAPI_INLINE
RtlLargeIntegerShiftLeft(
  IN LARGE_INTEGER LargeInteger,
  IN CCHAR ShiftCount)
{
  LARGE_INTEGER Result;

  Result.QuadPart = LargeInteger.QuadPart << ShiftCount;
  return Result;
}

//DECLSPEC_DEPRECATED_DDK_WINXP
static __inline
LARGE_INTEGER
NTAPI_INLINE
RtlLargeIntegerShiftRight(
  IN LARGE_INTEGER LargeInteger,
  IN CCHAR ShiftCount)
{
  LARGE_INTEGER Result;

  Result.QuadPart = (ULONG64)LargeInteger.QuadPart >> ShiftCount;
  return Result;
}

//DECLSPEC_DEPRECATED_DDK
static __inline
ULONG
NTAPI_INLINE
RtlEnlargedUnsignedDivide(
  IN ULARGE_INTEGER Dividend,
  IN ULONG Divisor,
  IN OUT PULONG Remainder)
{
  if (Remainder)
    *Remainder = (ULONG)(Dividend.QuadPart % Divisor);
  return (ULONG)(Dividend.QuadPart / Divisor);
}

//DECLSPEC_DEPRECATED_DDK
static __inline
LARGE_INTEGER
NTAPI_INLINE
RtlLargeIntegerNegate(
  IN LARGE_INTEGER Subtrahend)
{
  LARGE_INTEGER Difference;

  Difference.QuadPart = -Subtrahend.QuadPart;
  return Difference;
}

//DECLSPEC_DEPRECATED_DDK
static __inline
LARGE_INTEGER
NTAPI_INLINE
RtlLargeIntegerSubtract(
  IN LARGE_INTEGER Minuend,
  IN LARGE_INTEGER Subtrahend)
{
  LARGE_INTEGER Difference;

  Difference.QuadPart = Minuend.QuadPart - Subtrahend.QuadPart;
  return Difference;
}

//DECLSPEC_DEPRECATED_DDK
static __inline
LARGE_INTEGER
NTAPI_INLINE
RtlEnlargedUnsignedMultiply(
  IN ULONG Multiplicand,
  IN ULONG Multiplier)
{
  LARGE_INTEGER ret;
  ret.QuadPart = (ULONGLONG)Multiplicand * (ULONGLONG)Multiplier;
  return ret;
}

//DECLSPEC_DEPRECATED_DDK
static __inline
LARGE_INTEGER
NTAPI_INLINE
RtlEnlargedIntegerMultiply(
  IN LONG Multiplicand,
  IN LONG Multiplier)
{
  LARGE_INTEGER ret;
  ret.QuadPart = (LONGLONG)Multiplicand * (ULONGLONG)Multiplier;
  return ret;
}

FORCEINLINE
VOID
RtlInitEmptyAnsiString(
  OUT PANSI_STRING AnsiString,
  IN PCHAR Buffer,
  IN USHORT BufferSize)
{
  AnsiString->Length = 0;
  AnsiString->MaximumLength = BufferSize;
  AnsiString->Buffer = Buffer;
}

FORCEINLINE
VOID
RtlInitEmptyUnicodeString(
  OUT PUNICODE_STRING UnicodeString,
  IN PWSTR Buffer,
  IN USHORT BufferSize)
{
  UnicodeString->Length = 0;
  UnicodeString->MaximumLength = BufferSize;
  UnicodeString->Buffer = Buffer;
}

#if defined(_AMD64_) || defined(_IA64_)

static __inline
LARGE_INTEGER
NTAPI_INLINE
RtlExtendedIntegerMultiply(
  IN LARGE_INTEGER Multiplicand,
  IN LONG Multiplier)
{
  LARGE_INTEGER ret;
  ret.QuadPart = Multiplicand.QuadPart * Multiplier;
  return ret;
}

static __inline
LARGE_INTEGER
NTAPI_INLINE
RtlExtendedLargeIntegerDivide(
  IN LARGE_INTEGER Dividend,
  IN ULONG Divisor,
  OUT PULONG Remainder OPTIONAL)
{
  LARGE_INTEGER ret;
  ret.QuadPart = (ULONG64)Dividend.QuadPart / Divisor;
  if (Remainder)
    *Remainder = (ULONG)(Dividend.QuadPart % Divisor);
  return ret;
}

#endif /* defined(_AMD64_) || defined(_IA64_) */


#if defined(_AMD64_)

#define MultiplyHigh __mulh
#define UnsignedMultiplyHigh __umulh

//DECLSPEC_DEPRECATED_DDK
static __inline
LARGE_INTEGER
NTAPI_INLINE
RtlExtendedMagicDivide(
  IN LARGE_INTEGER Dividend,
  IN LARGE_INTEGER MagicDivisor,
  IN CCHAR ShiftCount)
{
  LARGE_INTEGER ret;
  ULONG64 ret64;
  BOOLEAN Pos;
  Pos = (Dividend.QuadPart >= 0);
  ret64 = UnsignedMultiplyHigh(Pos ? Dividend.QuadPart : -Dividend.QuadPart,
                               MagicDivisor.QuadPart);
  ret64 >>= ShiftCount;
  ret.QuadPart = Pos ? ret64 : -(LONG64)ret64;
  return ret;
}
#endif

//DECLSPEC_DEPRECATED_DDK
static __inline
LARGE_INTEGER
NTAPI_INLINE
RtlLargeIntegerAdd(
  IN LARGE_INTEGER Addend1,
  IN LARGE_INTEGER Addend2)
{
  LARGE_INTEGER ret;
  ret.QuadPart = Addend1.QuadPart + Addend2.QuadPart;
  return ret;
}

/* VOID
 * RtlLargeIntegerAnd(
 *     IN OUT LARGE_INTEGER Result,
 *     IN LARGE_INTEGER Source,
 *     IN LARGE_INTEGER Mask);
 */
#define RtlLargeIntegerAnd(Result, Source, Mask) \
    Result.QuadPart = Source.QuadPart & Mask.QuadPart

//DECLSPEC_DEPRECATED_DDK
static __inline
LARGE_INTEGER
NTAPI_INLINE
RtlLargeIntegerArithmeticShift(
  IN LARGE_INTEGER LargeInteger,
  IN CCHAR ShiftCount)
{
  LARGE_INTEGER ret;
  ret.QuadPart = LargeInteger.QuadPart >> ShiftCount;
  return ret;
}

/* BOOLEAN
 * RtlLargeIntegerEqualTo(
 *     IN LARGE_INTEGER  Operand1,
 *     IN LARGE_INTEGER  Operand2);
 */
#define RtlLargeIntegerEqualTo(X,Y) \
    (!(((X).LowPart ^ (Y).LowPart) | ((X).HighPart ^ (Y).HighPart)))

FORCEINLINE
PVOID
RtlSecureZeroMemory(
  OUT PVOID Pointer,
  IN SIZE_T Size)
{
  volatile char* vptr = (volatile char*)Pointer;
#if defined(_M_AMD64)
  __stosb((PUCHAR)vptr, 0, Size);
#else
  char * endptr = (char *)vptr + Size;
  while (vptr < endptr) {
    *vptr = 0; vptr++;
  }
#endif
   return Pointer;
}

#if defined(_M_AMD64)
FORCEINLINE
BOOLEAN
RtlCheckBit(
  IN PRTL_BITMAP BitMapHeader,
  IN ULONG BitPosition)
{
  return BitTest64((LONG64 CONST*)BitMapHeader->Buffer, (LONG64)BitPosition);
}
#else
#define RtlCheckBit(BMH,BP) (((((PLONG)(BMH)->Buffer)[(BP)/32]) >> ((BP)%32)) & 0x1)
#endif /* defined(_M_AMD64) */

#define RtlLargeIntegerGreaterThan(X,Y) (                              \
    (((X).HighPart == (Y).HighPart) && ((X).LowPart > (Y).LowPart)) || \
    ((X).HighPart > (Y).HighPart)                                      \
)

#define RtlLargeIntegerGreaterThanOrEqualTo(X,Y) (                      \
    (((X).HighPart == (Y).HighPart) && ((X).LowPart >= (Y).LowPart)) || \
    ((X).HighPart > (Y).HighPart)                                       \
)

#define RtlLargeIntegerNotEqualTo(X,Y) (                          \
    (((X).LowPart ^ (Y).LowPart) | ((X).HighPart ^ (Y).HighPart)) \
)

#define RtlLargeIntegerLessThan(X,Y) (                                 \
    (((X).HighPart == (Y).HighPart) && ((X).LowPart < (Y).LowPart)) || \
    ((X).HighPart < (Y).HighPart)                                      \
)

#define RtlLargeIntegerLessThanOrEqualTo(X,Y) (                         \
    (((X).HighPart == (Y).HighPart) && ((X).LowPart <= (Y).LowPart)) || \
    ((X).HighPart < (Y).HighPart)                                       \
)

#define RtlLargeIntegerGreaterThanZero(X) (       \
    (((X).HighPart == 0) && ((X).LowPart > 0)) || \
    ((X).HighPart > 0 )                           \
)

#define RtlLargeIntegerGreaterOrEqualToZero(X) ( (X).HighPart >= 0 )

#define RtlLargeIntegerEqualToZero(X) ( !((X).LowPart | (X).HighPart) )

#define RtlLargeIntegerNotEqualToZero(X) ( ((X).LowPart | (X).HighPart) )

#define RtlLargeIntegerLessThanZero(X) ( ((X).HighPart < 0) )

#define RtlLargeIntegerLessOrEqualToZero(X) ( ((X).HighPart < 0) || !((X).LowPart | (X).HighPart) )

#endif /* !defined(MIDL_PASS) */

/* Byte Swap Functions */
#if (defined(_M_IX86) && (_MSC_FULL_VER > 13009037 || defined(__GNUC__))) || \
    ((defined(_M_AMD64) || defined(_M_IA64)) \
        && (_MSC_FULL_VER > 13009175 || defined(__GNUC__)))

#define RtlUshortByteSwap(_x) _byteswap_ushort((USHORT)(_x))
#define RtlUlongByteSwap(_x) _byteswap_ulong((_x))
#define RtlUlonglongByteSwap(_x) _byteswap_uint64((_x))

#endif

#if DBG

#define ASSERT(exp) \
  (VOID)((!(exp)) ? \
    RtlAssert( (PVOID)#exp, (PVOID)__FILE__, __LINE__, NULL ), FALSE : TRUE)

#define ASSERTMSG(msg, exp) \
  (VOID)((!(exp)) ? \
    RtlAssert( (PVOID)#exp, (PVOID)__FILE__, __LINE__, (PCHAR)msg ), FALSE : TRUE)

#define RTL_SOFT_ASSERT(exp) \
  (VOID)((!(exp)) ? \
    DbgPrint("%s(%d): Soft assertion failed\n   Expression: %s\n", __FILE__, __LINE__, #exp), FALSE : TRUE)

#define RTL_SOFT_ASSERTMSG(msg, exp) \
  (VOID)((!(exp)) ? \
    DbgPrint("%s(%d): Soft assertion failed\n   Expression: %s\n   Message: %s\n", __FILE__, __LINE__, #exp, (msg)), FALSE : TRUE)

#define RTL_VERIFY(exp) ASSERT(exp)
#define RTL_VERIFYMSG(msg, exp) ASSERTMSG(msg, exp)

#define RTL_SOFT_VERIFY(exp) RTL_SOFT_ASSERT(exp)
#define RTL_SOFT_VERIFYMSG(msg, exp) RTL_SOFT_ASSERTMSG(msg, exp)

#if defined(_MSC_VER)

#define NT_ASSERT(exp) \
   ((!(exp)) ? \
      (__annotation(L"Debug", L"AssertFail", L#exp), \
       DbgRaiseAssertionFailure(), FALSE) : TRUE)

#define NT_ASSERTMSG(msg, exp) \
   ((!(exp)) ? \
      (__annotation(L"Debug", L"AssertFail", L##msg), \
      DbgRaiseAssertionFailure(), FALSE) : TRUE)

#define NT_ASSERTMSGW(msg, exp) \
    ((!(exp)) ? \
        (__annotation(L"Debug", L"AssertFail", msg), \
         DbgRaiseAssertionFailure(), FALSE) : TRUE)

#define NT_VERIFY     NT_ASSERT
#define NT_VERIFYMSG  NT_ASSERTMSG
#define NT_VERIFYMSGW NT_ASSERTMSGW

#else

/* GCC doesn't support __annotation (nor PDB) */
#define NT_ASSERT(exp) \
   (VOID)((!(exp)) ? (DbgRaiseAssertionFailure(), FALSE) : TRUE)

#define NT_ASSERTMSG NT_ASSERT
#define NT_ASSERTMSGW NT_ASSERT

#endif

#else /* !DBG */

#define ASSERT(exp) ((VOID) 0)
#define ASSERTMSG(msg, exp) ((VOID) 0)

#define RTL_SOFT_ASSERT(exp) ((VOID) 0)
#define RTL_SOFT_ASSERTMSG(msg, exp) ((VOID) 0)

#define RTL_VERIFY(exp) ((exp) ? TRUE : FALSE)
#define RTL_VERIFYMSG(msg, exp) ((exp) ? TRUE : FALSE)

#define RTL_SOFT_VERIFY(exp) ((exp) ? TRUE : FALSE)
#define RTL_SOFT_VERIFYMSG(msg, exp) ((exp) ? TRUE : FALSE)

#define NT_ASSERT(exp)          ((VOID)0)
#define NT_ASSERTMSG(msg, exp)  ((VOID)0)
#define NT_ASSERTMSGW(msg, exp) ((VOID)0)

#define NT_VERIFY(_exp)           ((_exp) ? TRUE : FALSE)
#define NT_VERIFYMSG(_msg, _exp ) ((_exp) ? TRUE : FALSE)
#define NT_VERIFYMSGW(_msg, _exp) ((_exp) ? TRUE : FALSE)

#endif /* DBG */

#define InitializeListHead32(ListHead) (\
    (ListHead)->Flink = (ListHead)->Blink = PtrToUlong((ListHead)))

#if !defined(_WINBASE_)

#if defined(_WIN64) && (defined(_NTDRIVER_) || defined(_NTDDK_) || defined(_NTIFS_) || defined(_NTHAL_) || defined(_NTOSP_))

NTKERNELAPI
VOID
InitializeSListHead(
  OUT PSLIST_HEADER SListHead);

#else

FORCEINLINE
VOID
InitializeSListHead(
  OUT PSLIST_HEADER SListHead)
{
#if defined(_IA64_)
  ULONG64 FeatureBits;
#endif

#if defined(_WIN64)
  if (((ULONG_PTR)SListHead & 0xf) != 0) {
    RtlRaiseStatus(STATUS_DATATYPE_MISALIGNMENT);
  }
#endif
  RtlZeroMemory(SListHead, sizeof(SLIST_HEADER));
#if defined(_IA64_)
  FeatureBits = __getReg(CV_IA64_CPUID4);
  if ((FeatureBits & KF_16BYTE_INSTR) != 0) {
    SListHead->Header16.HeaderType = 1;
    SListHead->Header16.Init = 1;
  }
#endif
}

#endif

#if defined(_WIN64)

#define InterlockedPopEntrySList(Head) \
    ExpInterlockedPopEntrySList(Head)

#define InterlockedPushEntrySList(Head, Entry) \
    ExpInterlockedPushEntrySList(Head, Entry)

#define InterlockedFlushSList(Head) \
    ExpInterlockedFlushSList(Head)

#define QueryDepthSList(Head) \
    ExQueryDepthSList(Head)

#else /* !defined(_WIN64) */

NTKERNELAPI
PSLIST_ENTRY
FASTCALL
InterlockedPopEntrySList(
  IN PSLIST_HEADER ListHead);

NTKERNELAPI
PSLIST_ENTRY
FASTCALL
InterlockedPushEntrySList(
  IN PSLIST_HEADER ListHead,
  IN PSLIST_ENTRY ListEntry);

#define InterlockedFlushSList(ListHead) \
    ExInterlockedFlushSList(ListHead)

#define QueryDepthSList(Head) \
    ExQueryDepthSList(Head)

#endif /* !defined(_WIN64) */

#endif /* !defined(_WINBASE_) */

#define RTL_CONTEXT_EX_OFFSET(ContextEx, Chunk) ((ContextEx)->Chunk.Offset)
#define RTL_CONTEXT_EX_LENGTH(ContextEx, Chunk) ((ContextEx)->Chunk.Length)
#define RTL_CONTEXT_EX_CHUNK(Base, Layout, Chunk)       \
    ((PVOID)((PCHAR)(Base) + RTL_CONTEXT_EX_OFFSET(Layout, Chunk)))
#define RTL_CONTEXT_OFFSET(Context, Chunk)              \
    RTL_CONTEXT_EX_OFFSET((PCONTEXT_EX)(Context + 1), Chunk)
#define RTL_CONTEXT_LENGTH(Context, Chunk)              \
    RTL_CONTEXT_EX_LENGTH((PCONTEXT_EX)(Context + 1), Chunk)
#define RTL_CONTEXT_CHUNK(Context, Chunk)               \
    RTL_CONTEXT_EX_CHUNK((PCONTEXT_EX)(Context + 1),    \
                         (PCONTEXT_EX)(Context + 1),    \
                         Chunk)

BOOLEAN
RTLVERLIB_DDI(RtlIsNtDdiVersionAvailable)(
  IN ULONG Version);

BOOLEAN
RTLVERLIB_DDI(RtlIsServicePackVersionInstalled)(
  IN ULONG Version);

#ifndef RtlIsNtDdiVersionAvailable
#define RtlIsNtDdiVersionAvailable WdmlibRtlIsNtDdiVersionAvailable
#endif

#ifndef RtlIsServicePackVersionInstalled
#define RtlIsServicePackVersionInstalled WdmlibRtlIsServicePackVersionInstalled
#endif

#define RtlInterlockedSetBits(Flags, Flag) \
    InterlockedOr((PLONG)(Flags), Flag)

#define RtlInterlockedAndBits(Flags, Flag) \
    InterlockedAnd((PLONG)(Flags), Flag)

#define RtlInterlockedClearBits(Flags, Flag) \
    RtlInterlockedAndBits(Flags, ~(Flag))

#define RtlInterlockedXorBits(Flags, Flag) \
    InterlockedXor(Flags, Flag)

#define RtlInterlockedSetBitsDiscardReturn(Flags, Flag) \
    (VOID) RtlInterlockedSetBits(Flags, Flag)

#define RtlInterlockedAndBitsDiscardReturn(Flags, Flag) \
    (VOID) RtlInterlockedAndBits(Flags, Flag)

#define RtlInterlockedClearBitsDiscardReturn(Flags, Flag) \
    RtlInterlockedAndBitsDiscardReturn(Flags, ~(Flag))


/******************************************************************************
 *                              Kernel Functions                              *
 ******************************************************************************/
NTKERNELAPI
VOID
NTAPI
KeInitializeEvent(
  OUT PRKEVENT Event,
  IN EVENT_TYPE Type,
  IN BOOLEAN State);

NTKERNELAPI
VOID
NTAPI
KeClearEvent(
  IN OUT PRKEVENT Event);

#if (NTDDI_VERSION >= NTDDI_WIN2K)

#if defined(_NTDDK_) || defined(_NTIFS_)
NTKERNELAPI
VOID
NTAPI
ProbeForRead(
  IN CONST VOID *Address, /* CONST is added */
  IN SIZE_T Length,
  IN ULONG Alignment);
#endif /* defined(_NTDDK_) || defined(_NTIFS_) */

NTKERNELAPI
VOID
NTAPI
ProbeForWrite(
  IN PVOID Address,
  IN SIZE_T Length,
  IN ULONG Alignment);

#if defined(SINGLE_GROUP_LEGACY_API)

NTKERNELAPI
VOID
NTAPI
KeRevertToUserAffinityThread(VOID);

NTKERNELAPI
VOID
NTAPI
KeSetSystemAffinityThread(
  IN KAFFINITY Affinity);

NTKERNELAPI
VOID
NTAPI
KeSetTargetProcessorDpc(
  IN OUT PRKDPC Dpc,
  IN CCHAR Number);

NTKERNELAPI
KAFFINITY
NTAPI
KeQueryActiveProcessors(VOID);
#endif /* defined(SINGLE_GROUP_LEGACY_API) */

#if !defined(_M_AMD64)
NTKERNELAPI
ULONGLONG
NTAPI
KeQueryInterruptTime(VOID);

NTKERNELAPI
VOID
NTAPI
KeQuerySystemTime(
  OUT PLARGE_INTEGER CurrentTime);
#endif /* !_M_AMD64 */

#if !defined(_X86_) && !defined(_M_ARM)
NTKERNELAPI
KIRQL
NTAPI
KeAcquireSpinLockRaiseToDpc(
  IN OUT PKSPIN_LOCK SpinLock);

#define KeAcquireSpinLock(SpinLock, OldIrql) \
    *(OldIrql) = KeAcquireSpinLockRaiseToDpc(SpinLock)

NTKERNELAPI
VOID
NTAPI
KeAcquireSpinLockAtDpcLevel(
  IN OUT PKSPIN_LOCK SpinLock);

NTKERNELAPI
VOID
NTAPI
KeReleaseSpinLock(
  IN OUT PKSPIN_LOCK SpinLock,
  IN KIRQL NewIrql);

NTKERNELAPI
VOID
NTAPI
KeReleaseSpinLockFromDpcLevel(
  IN OUT PKSPIN_LOCK SpinLock);
#endif /* !_X86_ */

#if defined(_X86_) && (defined(_WDM_INCLUDED_) || defined(WIN9X_COMPAT_SPINLOCK))
NTKERNELAPI
VOID
NTAPI
KeInitializeSpinLock(
  IN PKSPIN_LOCK SpinLock);
#else
FORCEINLINE
VOID
KeInitializeSpinLock(IN PKSPIN_LOCK SpinLock)
{
  /* Clear the lock */
  *SpinLock = 0;
}
#endif

NTKERNELAPI
DECLSPEC_NORETURN
VOID
NTAPI
KeBugCheckEx(
  IN ULONG BugCheckCode,
  IN ULONG_PTR BugCheckParameter1,
  IN ULONG_PTR BugCheckParameter2,
  IN ULONG_PTR BugCheckParameter3,
  IN ULONG_PTR BugCheckParameter4);

NTKERNELAPI
BOOLEAN
NTAPI
KeCancelTimer(
  IN OUT PKTIMER);

NTKERNELAPI
NTSTATUS
NTAPI
KeDelayExecutionThread(
  IN KPROCESSOR_MODE WaitMode,
  IN BOOLEAN Alertable,
  IN PLARGE_INTEGER Interval);

NTKERNELAPI
BOOLEAN
NTAPI
KeDeregisterBugCheckCallback(
  IN OUT PKBUGCHECK_CALLBACK_RECORD CallbackRecord);

NTKERNELAPI
VOID
NTAPI
KeEnterCriticalRegion(VOID);

NTKERNELAPI
VOID
NTAPI
KeInitializeDeviceQueue(
  OUT PKDEVICE_QUEUE DeviceQueue);

NTKERNELAPI
VOID
NTAPI
KeInitializeDpc(
  OUT PRKDPC Dpc,
  IN PKDEFERRED_ROUTINE DeferredRoutine,
  IN PVOID DeferredContext OPTIONAL);

NTKERNELAPI
VOID
NTAPI
KeInitializeMutex(
  OUT PRKMUTEX Mutex,
  IN ULONG Level);

NTKERNELAPI
VOID
NTAPI
KeInitializeSemaphore(
  OUT PRKSEMAPHORE Semaphore,
  IN LONG Count,
  IN LONG Limit);

NTKERNELAPI
VOID
NTAPI
KeInitializeTimer(
  OUT PKTIMER Timer);

NTKERNELAPI
VOID
NTAPI
KeInitializeTimerEx(
  OUT PKTIMER Timer,
  IN TIMER_TYPE Type);

NTKERNELAPI
BOOLEAN
NTAPI
KeInsertByKeyDeviceQueue(
  IN OUT PKDEVICE_QUEUE DeviceQueue,
  IN OUT PKDEVICE_QUEUE_ENTRY DeviceQueueEntry,
  IN ULONG SortKey);

NTKERNELAPI
BOOLEAN
NTAPI
KeInsertDeviceQueue(
  IN OUT PKDEVICE_QUEUE DeviceQueue,
  IN OUT PKDEVICE_QUEUE_ENTRY DeviceQueueEntry);

NTKERNELAPI
BOOLEAN
NTAPI
KeInsertQueueDpc(
  IN OUT PRKDPC Dpc,
  IN PVOID SystemArgument1 OPTIONAL,
  IN PVOID SystemArgument2 OPTIONAL);

NTKERNELAPI
VOID
NTAPI
KeLeaveCriticalRegion(VOID);

NTHALAPI
LARGE_INTEGER
NTAPI
KeQueryPerformanceCounter(
  OUT PLARGE_INTEGER PerformanceFrequency OPTIONAL);

NTKERNELAPI
KPRIORITY
NTAPI
KeQueryPriorityThread(
  IN PRKTHREAD Thread);

NTKERNELAPI
ULONG
NTAPI
KeQueryTimeIncrement(VOID);

NTKERNELAPI
LONG
NTAPI
KeReadStateEvent(
  IN PRKEVENT Event);

NTKERNELAPI
LONG
NTAPI
KeReadStateMutex(
  IN PRKMUTEX Mutex);

NTKERNELAPI
LONG
NTAPI
KeReadStateSemaphore(
  IN PRKSEMAPHORE Semaphore);

NTKERNELAPI
BOOLEAN
NTAPI
KeReadStateTimer(
  IN PKTIMER Timer);

NTKERNELAPI
BOOLEAN
NTAPI
KeRegisterBugCheckCallback(
  OUT PKBUGCHECK_CALLBACK_RECORD CallbackRecord,
  IN PKBUGCHECK_CALLBACK_ROUTINE CallbackRoutine,
  IN PVOID Buffer,
  IN ULONG Length,
  IN PUCHAR Component);

NTKERNELAPI
LONG
NTAPI
KeReleaseMutex(
  IN OUT PRKMUTEX Mutex,
  IN BOOLEAN Wait);

NTKERNELAPI
LONG
NTAPI
KeReleaseSemaphore(
  IN OUT PRKSEMAPHORE Semaphore,
  IN KPRIORITY Increment,
  IN LONG Adjustment,
  IN BOOLEAN Wait);

NTKERNELAPI
PKDEVICE_QUEUE_ENTRY
NTAPI
KeRemoveByKeyDeviceQueue(
  IN OUT PKDEVICE_QUEUE DeviceQueue,
  IN ULONG SortKey);

NTKERNELAPI
PKDEVICE_QUEUE_ENTRY
NTAPI
KeRemoveDeviceQueue(
  IN OUT PKDEVICE_QUEUE DeviceQueue);

NTKERNELAPI
BOOLEAN
NTAPI
KeRemoveEntryDeviceQueue(
  IN OUT PKDEVICE_QUEUE DeviceQueue,
  IN OUT PKDEVICE_QUEUE_ENTRY DeviceQueueEntry);

NTKERNELAPI
BOOLEAN
NTAPI
KeRemoveQueueDpc(
  IN OUT PRKDPC Dpc);

NTKERNELAPI
LONG
NTAPI
KeResetEvent(
  IN OUT PRKEVENT Event);

NTKERNELAPI
LONG
NTAPI
KeSetEvent(
  IN OUT PRKEVENT Event,
  IN KPRIORITY Increment,
  IN BOOLEAN Wait);

NTKERNELAPI
VOID
NTAPI
KeSetImportanceDpc(
  IN OUT PRKDPC Dpc,
  IN KDPC_IMPORTANCE Importance);

NTKERNELAPI
KPRIORITY
NTAPI
KeSetPriorityThread(
  IN OUT PKTHREAD Thread,
  IN KPRIORITY Priority);

NTKERNELAPI
BOOLEAN
NTAPI
KeSetTimer(
  IN OUT PKTIMER Timer,
  IN LARGE_INTEGER DueTime,
  IN PKDPC Dpc OPTIONAL);

NTKERNELAPI
BOOLEAN
NTAPI
KeSetTimerEx(
  IN OUT PKTIMER Timer,
  IN LARGE_INTEGER DueTime,
  IN LONG Period OPTIONAL,
  IN PKDPC Dpc OPTIONAL);

NTHALAPI
VOID
NTAPI
KeStallExecutionProcessor(
  IN ULONG MicroSeconds);

NTKERNELAPI
BOOLEAN
NTAPI
KeSynchronizeExecution(
  IN OUT PKINTERRUPT Interrupt,
  IN PKSYNCHRONIZE_ROUTINE SynchronizeRoutine,
  IN PVOID SynchronizeContext OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
KeWaitForMultipleObjects(
  IN ULONG Count,
  IN PVOID Object[],
  IN WAIT_TYPE WaitType,
  IN KWAIT_REASON WaitReason,
  IN KPROCESSOR_MODE WaitMode,
  IN BOOLEAN Alertable,
  IN PLARGE_INTEGER Timeout OPTIONAL,
  OUT PKWAIT_BLOCK WaitBlockArray OPTIONAL);

#define KeWaitForMutexObject KeWaitForSingleObject

NTKERNELAPI
NTSTATUS
NTAPI
KeWaitForSingleObject(
  IN PVOID Object,
  IN KWAIT_REASON WaitReason,
  IN KPROCESSOR_MODE WaitMode,
  IN BOOLEAN Alertable,
  IN PLARGE_INTEGER Timeout OPTIONAL);

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#if (NTDDI_VERSION >= NTDDI_WINXP)

_DECL_HAL_KE_IMPORT
VOID
FASTCALL
KeAcquireInStackQueuedSpinLock(
  IN OUT PKSPIN_LOCK SpinLock,
  OUT PKLOCK_QUEUE_HANDLE LockHandle);

NTKERNELAPI
VOID
FASTCALL
KeAcquireInStackQueuedSpinLockAtDpcLevel(
  IN OUT PKSPIN_LOCK SpinLock,
  OUT PKLOCK_QUEUE_HANDLE LockHandle);

NTKERNELAPI
KIRQL
NTAPI
KeAcquireInterruptSpinLock(
  IN OUT PKINTERRUPT Interrupt);

NTKERNELAPI
BOOLEAN
NTAPI
KeAreApcsDisabled(VOID);

NTKERNELAPI
ULONG
NTAPI
KeGetRecommendedSharedDataAlignment(VOID);

NTKERNELAPI
ULONG
NTAPI
KeQueryRuntimeThread(
  IN PKTHREAD Thread,
  OUT PULONG UserTime);

NTKERNELAPI
VOID
FASTCALL
KeReleaseInStackQueuedSpinLockFromDpcLevel(
  IN PKLOCK_QUEUE_HANDLE LockHandle);

NTKERNELAPI
VOID
NTAPI
KeReleaseInterruptSpinLock(
  IN OUT PKINTERRUPT Interrupt,
  IN KIRQL OldIrql);

NTKERNELAPI
PKDEVICE_QUEUE_ENTRY
NTAPI
KeRemoveByKeyDeviceQueueIfBusy(
  IN OUT PKDEVICE_QUEUE DeviceQueue,
  IN ULONG SortKey);

_DECL_HAL_KE_IMPORT
VOID
FASTCALL
KeReleaseInStackQueuedSpinLock(
  IN PKLOCK_QUEUE_HANDLE LockHandle);

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

#if (NTDDI_VERSION >= NTDDI_WINXPSP1)

NTKERNELAPI
BOOLEAN
NTAPI
KeDeregisterBugCheckReasonCallback(
  IN OUT PKBUGCHECK_REASON_CALLBACK_RECORD CallbackRecord);

NTKERNELAPI
BOOLEAN
NTAPI
KeRegisterBugCheckReasonCallback(
  OUT PKBUGCHECK_REASON_CALLBACK_RECORD CallbackRecord,
  IN PKBUGCHECK_REASON_CALLBACK_ROUTINE CallbackRoutine,
  IN KBUGCHECK_CALLBACK_REASON Reason,
  IN PUCHAR Component);

#endif /* (NTDDI_VERSION >= NTDDI_WINXPSP1) */

#if (NTDDI_VERSION >= NTDDI_WINXPSP2)
NTKERNELAPI
VOID
NTAPI
KeFlushQueuedDpcs(VOID);
#endif /* (NTDDI_VERSION >= NTDDI_WINXPSP2) */
#if (NTDDI_VERSION >= NTDDI_WS03)

NTKERNELAPI
PVOID
NTAPI
KeRegisterNmiCallback(
  IN PNMI_CALLBACK CallbackRoutine,
  IN PVOID Context OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
KeDeregisterNmiCallback(
  IN PVOID Handle);

NTKERNELAPI
VOID
NTAPI
KeInitializeThreadedDpc(
  OUT PRKDPC Dpc,
  IN PKDEFERRED_ROUTINE DeferredRoutine,
  IN PVOID DeferredContext OPTIONAL);

NTKERNELAPI
ULONG_PTR
NTAPI
KeIpiGenericCall(
  IN PKIPI_BROADCAST_WORKER BroadcastFunction,
  IN ULONG_PTR Context);

NTKERNELAPI
KIRQL
FASTCALL
KeAcquireSpinLockForDpc(
  IN OUT PKSPIN_LOCK SpinLock);

NTKERNELAPI
VOID
FASTCALL
KeReleaseSpinLockForDpc(
  IN OUT PKSPIN_LOCK SpinLock,
  IN KIRQL OldIrql);

NTKERNELAPI
BOOLEAN
FASTCALL
KeTestSpinLock(
  IN PKSPIN_LOCK SpinLock);

#endif /* (NTDDI_VERSION >= NTDDI_WS03) */

#if (NTDDI_VERSION >= NTDDI_WS03SP1)

NTKERNELAPI
BOOLEAN
FASTCALL
KeTryToAcquireSpinLockAtDpcLevel(
  IN OUT PKSPIN_LOCK SpinLock);

NTKERNELAPI
BOOLEAN
NTAPI
KeAreAllApcsDisabled(VOID);

NTKERNELAPI
VOID
FASTCALL
KeAcquireGuardedMutex(
  IN OUT PKGUARDED_MUTEX GuardedMutex);

NTKERNELAPI
VOID
FASTCALL
KeAcquireGuardedMutexUnsafe(
  IN OUT PKGUARDED_MUTEX GuardedMutex);

NTKERNELAPI
VOID
NTAPI
KeEnterGuardedRegion(VOID);

NTKERNELAPI
VOID
NTAPI
KeLeaveGuardedRegion(VOID);

NTKERNELAPI
VOID
FASTCALL
KeInitializeGuardedMutex(
  OUT PKGUARDED_MUTEX GuardedMutex);

NTKERNELAPI
VOID
FASTCALL
KeReleaseGuardedMutexUnsafe(
  IN OUT PKGUARDED_MUTEX GuardedMutex);

NTKERNELAPI
VOID
FASTCALL
KeReleaseGuardedMutex(
  IN OUT PKGUARDED_MUTEX GuardedMutex);

NTKERNELAPI
BOOLEAN
FASTCALL
KeTryToAcquireGuardedMutex(
  IN OUT PKGUARDED_MUTEX GuardedMutex);
#endif /* (NTDDI_VERSION >= NTDDI_WS03SP1) */

#if (NTDDI_VERSION >= NTDDI_VISTA)
NTKERNELAPI
VOID
FASTCALL
KeAcquireInStackQueuedSpinLockForDpc(
  IN OUT PKSPIN_LOCK SpinLock,
  OUT PKLOCK_QUEUE_HANDLE LockHandle);

NTKERNELAPI
VOID
FASTCALL
KeReleaseInStackQueuedSpinLockForDpc(
  IN PKLOCK_QUEUE_HANDLE LockHandle);

NTKERNELAPI
NTSTATUS
NTAPI
KeQueryDpcWatchdogInformation(
  OUT PKDPC_WATCHDOG_INFORMATION WatchdogInformation);
#if defined(SINGLE_GROUP_LEGACY_API)

NTKERNELAPI
KAFFINITY
NTAPI
KeSetSystemAffinityThreadEx(
  IN KAFFINITY Affinity);

NTKERNELAPI
VOID
NTAPI
KeRevertToUserAffinityThreadEx(
  IN KAFFINITY Affinity);

NTKERNELAPI
ULONG
NTAPI
KeQueryActiveProcessorCount(
  OUT PKAFFINITY ActiveProcessors OPTIONAL);

NTKERNELAPI
ULONG
NTAPI
KeQueryMaximumProcessorCount(VOID);
#endif /* SINGLE_GROUP_LEGACY_API */

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#if (NTDDI_VERSION >= NTDDI_WS08)

PVOID
KeRegisterProcessorChangeCallback(
  IN PPROCESSOR_CALLBACK_FUNCTION CallbackFunction,
  IN PVOID CallbackContext OPTIONAL,
  IN ULONG Flags);

VOID
KeDeregisterProcessorChangeCallback(
  IN PVOID CallbackHandle);

#endif /* (NTDDI_VERSION >= NTDDI_WS08) */
#if (NTDDI_VERSION >= NTDDI_WIN7)

ULONG64
NTAPI
KeQueryTotalCycleTimeProcess(
  IN OUT PKPROCESS Process,
  OUT PULONG64 CycleTimeStamp);

ULONG64
NTAPI
KeQueryTotalCycleTimeThread(
  IN OUT PKTHREAD Thread,
  OUT PULONG64 CycleTimeStamp);

NTKERNELAPI
NTSTATUS
NTAPI
KeSetTargetProcessorDpcEx(
  IN OUT PKDPC Dpc,
  IN PPROCESSOR_NUMBER ProcNumber);

NTKERNELAPI
VOID
NTAPI
KeSetSystemGroupAffinityThread(
  IN PGROUP_AFFINITY Affinity,
  OUT PGROUP_AFFINITY PreviousAffinity OPTIONAL);

NTKERNELAPI
VOID
NTAPI
KeRevertToUserGroupAffinityThread(
  IN PGROUP_AFFINITY PreviousAffinity);

NTKERNELAPI
BOOLEAN
NTAPI
KeSetCoalescableTimer(
  IN OUT PKTIMER Timer,
  IN LARGE_INTEGER DueTime,
  IN ULONG Period,
  IN ULONG TolerableDelay,
  IN PKDPC Dpc OPTIONAL);

NTKERNELAPI
ULONGLONG
NTAPI
KeQueryUnbiasedInterruptTime(VOID);

NTKERNELAPI
ULONG
NTAPI
KeQueryActiveProcessorCountEx(
  IN USHORT GroupNumber);

NTKERNELAPI
ULONG
NTAPI
KeQueryMaximumProcessorCountEx(
  IN USHORT GroupNumber);

NTKERNELAPI
USHORT
NTAPI
KeQueryActiveGroupCount(VOID);

NTKERNELAPI
USHORT
NTAPI
KeQueryMaximumGroupCount(VOID);

NTKERNELAPI
KAFFINITY
NTAPI
KeQueryGroupAffinity(
  IN USHORT GroupNumber);

NTKERNELAPI
ULONG
NTAPI
KeGetCurrentProcessorNumberEx(
  OUT PPROCESSOR_NUMBER ProcNumber OPTIONAL);

NTKERNELAPI
VOID
NTAPI
KeQueryNodeActiveAffinity(
  IN USHORT NodeNumber,
  OUT PGROUP_AFFINITY Affinity OPTIONAL,
  OUT PUSHORT Count OPTIONAL);

NTKERNELAPI
USHORT
NTAPI
KeQueryNodeMaximumProcessorCount(
  IN USHORT NodeNumber);

NTKERNELAPI
USHORT
NTAPI
KeQueryHighestNodeNumber(VOID);

NTKERNELAPI
USHORT
NTAPI
KeGetCurrentNodeNumber(VOID);

NTKERNELAPI
NTSTATUS
NTAPI
KeQueryLogicalProcessorRelationship(
  IN PPROCESSOR_NUMBER ProcessorNumber OPTIONAL,
  IN LOGICAL_PROCESSOR_RELATIONSHIP RelationshipType,
  OUT PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX Information OPTIONAL,
  IN OUT PULONG Length);

NTKERNELAPI
NTSTATUS
NTAPI
KeSaveExtendedProcessorState(
  IN ULONG64 Mask,
  OUT PXSTATE_SAVE XStateSave);

NTKERNELAPI
VOID
NTAPI
KeRestoreExtendedProcessorState(
  IN PXSTATE_SAVE XStateSave);

NTSTATUS
NTAPI
KeGetProcessorNumberFromIndex(
  IN ULONG ProcIndex,
  OUT PPROCESSOR_NUMBER ProcNumber);

ULONG
NTAPI
KeGetProcessorIndexFromNumber(
  IN PPROCESSOR_NUMBER ProcNumber);
#endif /* (NTDDI_VERSION >= NTDDI_WIN7) */
#if !defined(_IA64_)
NTHALAPI
VOID
NTAPI
KeFlushWriteBuffer(VOID);
#endif

/* VOID
 * KeInitializeCallbackRecord(
 *   IN PKBUGCHECK_CALLBACK_RECORD  CallbackRecord)
 */
#define KeInitializeCallbackRecord(CallbackRecord) \
  CallbackRecord->State = BufferEmpty;

#if DBG

#if (NTDDI_VERSION >= NTDDI_VISTA)
#define PAGED_ASSERT( exp ) NT_ASSERT( exp )
#else
#define PAGED_ASSERT( exp ) ASSERT( exp )
#endif

#define PAGED_CODE() { \
  if (KeGetCurrentIrql() > APC_LEVEL) { \
    KdPrint( ("NTDDK: Pageable code called at IRQL > APC_LEVEL (%d)\n", KeGetCurrentIrql() )); \
    PAGED_ASSERT(FALSE); \
  } \
}

#else

#define PAGED_CODE()

#endif /* DBG */

#define PAGED_CODE_LOCKED() NOP_FUNCTION;

/******************************************************************************
 *                       Memory manager Functions                             *
 ******************************************************************************/
/* Alignment Macros */
#define ALIGN_DOWN_BY(size, align) \
    ((ULONG_PTR)(size) & ~((ULONG_PTR)(align) - 1))

#define ALIGN_UP_BY(size, align) \
    (ALIGN_DOWN_BY(((ULONG_PTR)(size) + align - 1), align))

#define ALIGN_DOWN_POINTER_BY(ptr, align) \
    ((PVOID)ALIGN_DOWN_BY(ptr, align))

#define ALIGN_UP_POINTER_BY(ptr, align) \
    ((PVOID)ALIGN_UP_BY(ptr, align))

#define ALIGN_DOWN(size, type) \
    ALIGN_DOWN_BY(size, sizeof(type))

#define ALIGN_UP(size, type) \
    ALIGN_UP_BY(size, sizeof(type))

#define ALIGN_DOWN_POINTER(ptr, type) \
    ALIGN_DOWN_POINTER_BY(ptr, sizeof(type))

#define ALIGN_UP_POINTER(ptr, type) \
    ALIGN_UP_POINTER_BY(ptr, sizeof(type))

#ifndef FIELD_OFFSET
#define FIELD_OFFSET(type, field) ((ULONG)&(((type *)0)->field))
#endif

#ifndef FIELD_SIZE
#define FIELD_SIZE(type, field) (sizeof(((type *)0)->field))
#endif

#define POOL_TAGGING                             1

#if DBG
#define IF_DEBUG if (TRUE)
#else
#define IF_DEBUG if (FALSE)
#endif /* DBG */

/* ULONG
 * BYTE_OFFSET(
 *   IN PVOID Va)
 */
#define BYTE_OFFSET(Va) \
  ((ULONG) ((ULONG_PTR) (Va) & (PAGE_SIZE - 1)))

/* ULONG
 * BYTES_TO_PAGES(
 *   IN ULONG Size)
 *
 * Note: This needs to be like this to avoid overflows!
 */
#define BYTES_TO_PAGES(Size) \
  (((Size) >> PAGE_SHIFT) + (((Size) & (PAGE_SIZE - 1)) != 0))

/* PVOID
 * PAGE_ALIGN(
 *   IN PVOID Va)
 */
#define PAGE_ALIGN(Va) \
  ((PVOID) ((ULONG_PTR)(Va) & ~(PAGE_SIZE - 1)))

/* ULONG_PTR
 * ROUND_TO_PAGES(
 *   IN ULONG_PTR Size)
 */
#define ROUND_TO_PAGES(Size) \
  (((ULONG_PTR) (Size) + PAGE_SIZE - 1) & ~(PAGE_SIZE - 1))

/* ULONG
 * ADDRESS_AND_SIZE_TO_SPAN_PAGES(
 *   IN PVOID Va,
 *   IN ULONG Size)
 */
#define ADDRESS_AND_SIZE_TO_SPAN_PAGES(_Va, _Size) \
  ((ULONG) ((((ULONG_PTR) (_Va) & (PAGE_SIZE - 1)) \
    + (_Size) + (PAGE_SIZE - 1)) >> PAGE_SHIFT))

#define COMPUTE_PAGES_SPANNED(Va, Size) \
    ADDRESS_AND_SIZE_TO_SPAN_PAGES(Va,Size)

/*
 * ULONG
 * MmGetMdlByteCount(
 *   IN PMDL  Mdl)
 */
#define MmGetMdlByteCount(_Mdl) \
  ((_Mdl)->ByteCount)

/*
 * ULONG
 * MmGetMdlByteOffset(
 *   IN PMDL  Mdl)
 */
#define MmGetMdlByteOffset(_Mdl) \
  ((_Mdl)->ByteOffset)

#define MmGetMdlBaseVa(Mdl) ((Mdl)->StartVa)

/*
 * PPFN_NUMBER
 * MmGetMdlPfnArray(
 *   IN PMDL  Mdl)
 */
#define MmGetMdlPfnArray(_Mdl) \
  ((PPFN_NUMBER) ((_Mdl) + 1))

/*
 * PVOID
 * MmGetMdlVirtualAddress(
 *   IN PMDL  Mdl)
 */
#define MmGetMdlVirtualAddress(_Mdl) \
  ((PVOID) ((PCHAR) ((_Mdl)->StartVa) + (_Mdl)->ByteOffset))

#define MmGetProcedureAddress(Address) (Address)
#define MmLockPagableCodeSection(Address) MmLockPagableDataSection(Address)

/* PVOID MmGetSystemAddressForMdl(
 *     IN PMDL Mdl);
 */
#define MmGetSystemAddressForMdl(Mdl) \
  (((Mdl)->MdlFlags & (MDL_MAPPED_TO_SYSTEM_VA | \
    MDL_SOURCE_IS_NONPAGED_POOL)) ? \
      ((Mdl)->MappedSystemVa) : \
      (MmMapLockedPages((Mdl), KernelMode)))

/* PVOID
 * MmGetSystemAddressForMdlSafe(
 *     IN PMDL Mdl,
 *     IN MM_PAGE_PRIORITY Priority)
 */
#define MmGetSystemAddressForMdlSafe(_Mdl, _Priority) \
  (((_Mdl)->MdlFlags & (MDL_MAPPED_TO_SYSTEM_VA \
    | MDL_SOURCE_IS_NONPAGED_POOL)) ? \
    (_Mdl)->MappedSystemVa : \
    (PVOID) MmMapLockedPagesSpecifyCache((_Mdl), \
      KernelMode, MmCached, NULL, FALSE, (_Priority)))

/*
 * VOID
 * MmInitializeMdl(
 *   IN PMDL  MemoryDescriptorList,
 *   IN PVOID  BaseVa,
 *   IN SIZE_T  Length)
 */
#define MmInitializeMdl(_MemoryDescriptorList, \
                        _BaseVa, \
                        _Length) \
{ \
  (_MemoryDescriptorList)->Next = (PMDL) NULL; \
  (_MemoryDescriptorList)->Size = (CSHORT) (sizeof(MDL) + \
    (sizeof(PFN_NUMBER) * ADDRESS_AND_SIZE_TO_SPAN_PAGES(_BaseVa, _Length))); \
  (_MemoryDescriptorList)->MdlFlags = 0; \
  (_MemoryDescriptorList)->StartVa = (PVOID) PAGE_ALIGN(_BaseVa); \
  (_MemoryDescriptorList)->ByteOffset = BYTE_OFFSET(_BaseVa); \
  (_MemoryDescriptorList)->ByteCount = (ULONG) _Length; \
}

/*
 * VOID
 * MmPrepareMdlForReuse(
 *   IN PMDL  Mdl)
 */
#define MmPrepareMdlForReuse(_Mdl) \
{ \
  if (((_Mdl)->MdlFlags & MDL_PARTIAL_HAS_BEEN_MAPPED) != 0) { \
    ASSERT(((_Mdl)->MdlFlags & MDL_PARTIAL) != 0); \
    MmUnmapLockedPages((_Mdl)->MappedSystemVa, (_Mdl)); \
  } else if (((_Mdl)->MdlFlags & MDL_PARTIAL) == 0) { \
    ASSERT(((_Mdl)->MdlFlags & MDL_MAPPED_TO_SYSTEM_VA) == 0); \
  } \
}

#if (NTDDI_VERSION >= NTDDI_WIN2K)
NTKERNELAPI
PVOID
NTAPI
MmAllocateContiguousMemory(
  IN SIZE_T NumberOfBytes,
  IN PHYSICAL_ADDRESS HighestAcceptableAddress);

NTKERNELAPI
PVOID
NTAPI
MmAllocateContiguousMemorySpecifyCache(
  IN SIZE_T NumberOfBytes,
  IN PHYSICAL_ADDRESS LowestAcceptableAddress,
  IN PHYSICAL_ADDRESS HighestAcceptableAddress,
  IN PHYSICAL_ADDRESS BoundaryAddressMultiple OPTIONAL,
  IN MEMORY_CACHING_TYPE CacheType);

NTKERNELAPI
PMDL
NTAPI
MmAllocatePagesForMdl(
  IN PHYSICAL_ADDRESS LowAddress,
  IN PHYSICAL_ADDRESS HighAddress,
  IN PHYSICAL_ADDRESS SkipBytes,
  IN SIZE_T TotalBytes);

NTKERNELAPI
VOID
NTAPI
MmBuildMdlForNonPagedPool(
  IN OUT PMDLX MemoryDescriptorList);

//DECLSPEC_DEPRECATED_DDK
NTKERNELAPI
PMDL
NTAPI
MmCreateMdl(
  IN PMDL MemoryDescriptorList OPTIONAL,
  IN PVOID Base,
  IN SIZE_T Length);

NTKERNELAPI
VOID
NTAPI
MmFreeContiguousMemory(
  IN PVOID BaseAddress);

NTKERNELAPI
VOID
NTAPI
MmFreeContiguousMemorySpecifyCache(
  IN PVOID BaseAddress,
  IN SIZE_T NumberOfBytes,
  IN MEMORY_CACHING_TYPE CacheType);

NTKERNELAPI
VOID
NTAPI
MmFreePagesFromMdl(
  IN PMDLX MemoryDescriptorList);

NTKERNELAPI
PVOID
NTAPI
MmGetSystemRoutineAddress(
  IN PUNICODE_STRING SystemRoutineName);

NTKERNELAPI
LOGICAL
NTAPI
MmIsDriverVerifying(
  IN struct _DRIVER_OBJECT *DriverObject);

NTKERNELAPI
PVOID
NTAPI
MmLockPagableDataSection(
  IN PVOID AddressWithinSection);

NTKERNELAPI
PVOID
NTAPI
MmMapIoSpace(
  IN PHYSICAL_ADDRESS PhysicalAddress,
  IN SIZE_T NumberOfBytes,
  IN MEMORY_CACHING_TYPE CacheEnable);

NTKERNELAPI
PVOID
NTAPI
MmMapLockedPages(
  IN PMDL MemoryDescriptorList,
  IN KPROCESSOR_MODE AccessMode);

NTKERNELAPI
PVOID
NTAPI
MmMapLockedPagesSpecifyCache(
  IN PMDLX MemoryDescriptorList,
  IN KPROCESSOR_MODE AccessMode,
  IN MEMORY_CACHING_TYPE CacheType,
  IN PVOID BaseAddress OPTIONAL,
  IN ULONG BugCheckOnFailure,
  IN MM_PAGE_PRIORITY Priority);

NTKERNELAPI
PVOID
NTAPI
MmPageEntireDriver(
  IN PVOID AddressWithinSection);

NTKERNELAPI
VOID
NTAPI
MmProbeAndLockPages(
  IN OUT PMDL MemoryDescriptorList,
  IN KPROCESSOR_MODE AccessMode,
  IN LOCK_OPERATION Operation);

NTKERNELAPI
MM_SYSTEMSIZE
NTAPI
MmQuerySystemSize(VOID);

NTKERNELAPI
VOID
NTAPI
MmResetDriverPaging(
  IN PVOID AddressWithinSection);

NTKERNELAPI
SIZE_T
NTAPI
MmSizeOfMdl(
  IN PVOID Base,
  IN SIZE_T Length);

NTKERNELAPI
VOID
NTAPI
MmUnlockPagableImageSection(
  IN PVOID ImageSectionHandle);

NTKERNELAPI
VOID
NTAPI
MmUnlockPages(
  IN OUT PMDL MemoryDescriptorList);

NTKERNELAPI
VOID
NTAPI
MmUnmapIoSpace(
  IN PVOID BaseAddress,
  IN SIZE_T NumberOfBytes);

NTKERNELAPI
VOID
NTAPI
MmProbeAndLockProcessPages(
  IN OUT PMDL MemoryDescriptorList,
  IN PEPROCESS Process,
  IN KPROCESSOR_MODE AccessMode,
  IN LOCK_OPERATION Operation);

NTKERNELAPI
VOID
NTAPI
MmUnmapLockedPages(
  IN PVOID BaseAddress,
  IN PMDL MemoryDescriptorList);

NTKERNELAPI
PVOID
NTAPI
MmAllocateContiguousMemorySpecifyCacheNode(
  IN SIZE_T NumberOfBytes,
  IN PHYSICAL_ADDRESS LowestAcceptableAddress,
  IN PHYSICAL_ADDRESS HighestAcceptableAddress,
  IN PHYSICAL_ADDRESS BoundaryAddressMultiple OPTIONAL,
  IN MEMORY_CACHING_TYPE CacheType,
  IN NODE_REQUIREMENT PreferredNode);

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#if (NTDDI_VERSION >= NTDDI_WINXP)

NTKERNELAPI
NTSTATUS
NTAPI
MmAdvanceMdl(
  IN OUT PMDL Mdl,
  IN ULONG NumberOfBytes);

NTKERNELAPI
PVOID
NTAPI
MmAllocateMappingAddress(
  IN SIZE_T NumberOfBytes,
  IN ULONG PoolTag);

NTKERNELAPI
VOID
NTAPI
MmFreeMappingAddress(
  IN PVOID BaseAddress,
  IN ULONG PoolTag);

NTKERNELAPI
NTSTATUS
NTAPI
MmIsVerifierEnabled(
  OUT PULONG VerifierFlags);

NTKERNELAPI
PVOID
NTAPI
MmMapLockedPagesWithReservedMapping(
  IN PVOID MappingAddress,
  IN ULONG PoolTag,
  IN PMDL MemoryDescriptorList,
  IN MEMORY_CACHING_TYPE CacheType);

NTKERNELAPI
NTSTATUS
NTAPI
MmProtectMdlSystemAddress(
  IN PMDL MemoryDescriptorList,
  IN ULONG NewProtect);

NTKERNELAPI
VOID
NTAPI
MmUnmapReservedMapping(
  IN PVOID BaseAddress,
  IN ULONG PoolTag,
  IN PMDL MemoryDescriptorList);

NTKERNELAPI
NTSTATUS
NTAPI
MmAddVerifierThunks(
  IN PVOID ThunkBuffer,
  IN ULONG ThunkBufferSize);

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

#if (NTDDI_VERSION >= NTDDI_WS03)
NTKERNELAPI
LOGICAL
NTAPI
MmIsIoSpaceActive(
  IN PHYSICAL_ADDRESS StartAddress,
  IN SIZE_T NumberOfBytes);

#endif /* (NTDDI_VERSION >= NTDDI_WS03) */
#if (NTDDI_VERSION >= NTDDI_WS03SP1)
NTKERNELAPI
PMDL
NTAPI
MmAllocatePagesForMdlEx(
  IN PHYSICAL_ADDRESS LowAddress,
  IN PHYSICAL_ADDRESS HighAddress,
  IN PHYSICAL_ADDRESS SkipBytes,
  IN SIZE_T TotalBytes,
  IN MEMORY_CACHING_TYPE CacheType,
  IN ULONG Flags);
#endif

#if (NTDDI_VERSION >= NTDDI_VISTA)
NTKERNELAPI
LOGICAL
NTAPI
MmIsDriverVerifyingByAddress(
  IN PVOID AddressWithinSection);
#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

/******************************************************************************
 *                            Security Manager Functions                      *
 ******************************************************************************/

#if (NTDDI_VERSION >= NTDDI_WIN2K)
NTKERNELAPI
BOOLEAN
NTAPI
SeAccessCheck(
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN PSECURITY_SUBJECT_CONTEXT SubjectSecurityContext,
  IN BOOLEAN SubjectContextLocked,
  IN ACCESS_MASK DesiredAccess,
  IN ACCESS_MASK PreviouslyGrantedAccess,
  OUT PPRIVILEGE_SET *Privileges OPTIONAL,
  IN PGENERIC_MAPPING GenericMapping,
  IN KPROCESSOR_MODE AccessMode,
  OUT PACCESS_MASK GrantedAccess,
  OUT PNTSTATUS AccessStatus);

NTKERNELAPI
NTSTATUS
NTAPI
SeAssignSecurity(
  IN PSECURITY_DESCRIPTOR ParentDescriptor OPTIONAL,
  IN PSECURITY_DESCRIPTOR ExplicitDescriptor OPTIONAL,
  OUT PSECURITY_DESCRIPTOR *NewDescriptor,
  IN BOOLEAN IsDirectoryObject,
  IN PSECURITY_SUBJECT_CONTEXT SubjectContext,
  IN PGENERIC_MAPPING GenericMapping,
  IN POOL_TYPE PoolType);

NTKERNELAPI
NTSTATUS
NTAPI
SeAssignSecurityEx(
  IN PSECURITY_DESCRIPTOR ParentDescriptor OPTIONAL,
  IN PSECURITY_DESCRIPTOR ExplicitDescriptor OPTIONAL,
  OUT PSECURITY_DESCRIPTOR *NewDescriptor,
  IN GUID *ObjectType OPTIONAL,
  IN BOOLEAN IsDirectoryObject,
  IN ULONG AutoInheritFlags,
  IN PSECURITY_SUBJECT_CONTEXT SubjectContext,
  IN PGENERIC_MAPPING GenericMapping,
  IN POOL_TYPE PoolType);

NTKERNELAPI
NTSTATUS
NTAPI
SeDeassignSecurity(
  IN OUT PSECURITY_DESCRIPTOR *SecurityDescriptor);

NTKERNELAPI
BOOLEAN
NTAPI
SeValidSecurityDescriptor(
  IN ULONG Length,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor);

NTKERNELAPI
ULONG
NTAPI
SeObjectCreateSaclAccessBits(
  IN PSECURITY_DESCRIPTOR SecurityDescriptor);

NTKERNELAPI
VOID
NTAPI
SeReleaseSubjectContext(
  IN OUT PSECURITY_SUBJECT_CONTEXT SubjectContext);

NTKERNELAPI
VOID
NTAPI
SeUnlockSubjectContext(
  IN PSECURITY_SUBJECT_CONTEXT SubjectContext);

NTKERNELAPI
VOID
NTAPI
SeCaptureSubjectContext(
  OUT PSECURITY_SUBJECT_CONTEXT SubjectContext);

NTKERNELAPI
VOID
NTAPI
SeLockSubjectContext(
  IN PSECURITY_SUBJECT_CONTEXT SubjectContext);

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#if (NTDDI_VERSION >= NTDDI_WS03SP1)

NTSTATUS
NTAPI
SeSetAuditParameter(
  IN OUT PSE_ADT_PARAMETER_ARRAY AuditParameters,
  IN SE_ADT_PARAMETER_TYPE Type,
  IN ULONG Index,
  IN PVOID Data);

NTSTATUS
NTAPI
SeReportSecurityEvent(
  IN ULONG Flags,
  IN PUNICODE_STRING SourceName,
  IN PSID UserSid OPTIONAL,
  IN PSE_ADT_PARAMETER_ARRAY AuditParameters);

#endif /* (NTDDI_VERSION >= NTDDI_WS03SP1) */

#if (NTDDI_VERSION >= NTDDI_VISTA)
NTKERNELAPI
ULONG
NTAPI
SeComputeAutoInheritByObjectType(
  IN PVOID ObjectType,
  IN PSECURITY_DESCRIPTOR SecurityDescriptor OPTIONAL,
  IN PSECURITY_DESCRIPTOR ParentSecurityDescriptor OPTIONAL);

#ifdef SE_NTFS_WORLD_CACHE
VOID
NTAPI
SeGetWorldRights(
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN PGENERIC_MAPPING GenericMapping,
  OUT PACCESS_MASK GrantedAccess);
#endif /* SE_NTFS_WORLD_CACHE */
#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

/******************************************************************************
 *                         Configuration Manager Functions                    *
 ******************************************************************************/

#if (NTDDI_VERSION >= NTDDI_WINXP)
NTKERNELAPI
NTSTATUS
NTAPI
CmRegisterCallback(
  IN PEX_CALLBACK_FUNCTION Function,
  IN PVOID Context OPTIONAL,
  OUT PLARGE_INTEGER Cookie);

NTKERNELAPI
NTSTATUS
NTAPI
CmUnRegisterCallback(
  IN LARGE_INTEGER Cookie);
#endif

#if (NTDDI_VERSION >= NTDDI_VISTA)

NTKERNELAPI
NTSTATUS
NTAPI
CmRegisterCallbackEx(
  PEX_CALLBACK_FUNCTION Function,
  PCUNICODE_STRING Altitude,
  PVOID Driver,
  PVOID Context,
  PLARGE_INTEGER Cookie,
  PVOID Reserved);

NTKERNELAPI
VOID
NTAPI
CmGetCallbackVersion(
  OUT PULONG Major OPTIONAL,
  OUT PULONG Minor OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
CmSetCallbackObjectContext(
  IN OUT PVOID Object,
  IN PLARGE_INTEGER Cookie,
  IN PVOID NewContext,
  OUT PVOID *OldContext OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
CmCallbackGetKeyObjectID(
  IN PLARGE_INTEGER Cookie,
  IN PVOID Object,
  OUT PULONG_PTR ObjectID OPTIONAL,
  OUT PCUNICODE_STRING *ObjectName OPTIONAL);

NTKERNELAPI
PVOID
NTAPI
CmGetBoundTransaction(
  IN PLARGE_INTEGER Cookie,
  IN PVOID Object);

#endif // NTDDI_VERSION >= NTDDI_VISTA


/******************************************************************************
 *                         I/O Manager Functions                              *
 ******************************************************************************/

/*
 * NTSTATUS
 * IoAcquireRemoveLock(
 *   IN PIO_REMOVE_LOCK  RemoveLock,
 *   IN OPTIONAL PVOID  Tag)
 */
#if DBG
#define IoAcquireRemoveLock(RemoveLock, Tag) \
  IoAcquireRemoveLockEx(RemoveLock, Tag, __FILE__, __LINE__, sizeof (IO_REMOVE_LOCK))
#else
#define IoAcquireRemoveLock(RemoveLock, Tag) \
  IoAcquireRemoveLockEx(RemoveLock, Tag, "", 1, sizeof (IO_REMOVE_LOCK))
#endif

/*
 * VOID
 * IoAdjustPagingPathCount(
 *   IN PLONG  Count,
 *   IN BOOLEAN  Increment)
 */
#define IoAdjustPagingPathCount(_Count, \
                                _Increment) \
{ \
  if (_Increment) \
    { \
      InterlockedIncrement(_Count); \
    } \
  else \
    { \
      InterlockedDecrement(_Count); \
    } \
}

#if !defined(_M_AMD64)
NTHALAPI
VOID
NTAPI
READ_PORT_BUFFER_UCHAR(
  IN PUCHAR Port,
  IN PUCHAR Buffer,
  IN ULONG Count);

NTHALAPI
VOID
NTAPI
READ_PORT_BUFFER_ULONG(
  IN PULONG Port,
  IN PULONG Buffer,
  IN ULONG Count);

NTHALAPI
VOID
NTAPI
READ_PORT_BUFFER_USHORT(
  IN PUSHORT Port,
  IN PUSHORT Buffer,
  IN ULONG Count);

NTHALAPI
UCHAR
NTAPI
READ_PORT_UCHAR(
  IN PUCHAR Port);

NTHALAPI
ULONG
NTAPI
READ_PORT_ULONG(
  IN PULONG Port);

NTHALAPI
USHORT
NTAPI
READ_PORT_USHORT(
  IN PUSHORT Port);

NTKERNELAPI
VOID
NTAPI
READ_REGISTER_BUFFER_UCHAR(
  IN PUCHAR Register,
  IN PUCHAR Buffer,
  IN ULONG Count);

NTKERNELAPI
VOID
NTAPI
READ_REGISTER_BUFFER_ULONG(
  IN PULONG Register,
  IN PULONG Buffer,
  IN ULONG Count);

NTKERNELAPI
VOID
NTAPI
READ_REGISTER_BUFFER_USHORT(
  IN PUSHORT Register,
  IN PUSHORT Buffer,
  IN ULONG Count);

NTKERNELAPI
UCHAR
NTAPI
READ_REGISTER_UCHAR(
  IN PUCHAR Register);

NTKERNELAPI
ULONG
NTAPI
READ_REGISTER_ULONG(
  IN PULONG Register);

NTKERNELAPI
USHORT
NTAPI
READ_REGISTER_USHORT(
  IN PUSHORT Register);

NTHALAPI
VOID
NTAPI
WRITE_PORT_BUFFER_UCHAR(
  IN PUCHAR Port,
  IN PUCHAR Buffer,
  IN ULONG Count);

NTHALAPI
VOID
NTAPI
WRITE_PORT_BUFFER_ULONG(
  IN PULONG Port,
  IN PULONG Buffer,
  IN ULONG Count);

NTHALAPI
VOID
NTAPI
WRITE_PORT_BUFFER_USHORT(
  IN PUSHORT Port,
  IN PUSHORT Buffer,
  IN ULONG Count);

NTHALAPI
VOID
NTAPI
WRITE_PORT_UCHAR(
  IN PUCHAR Port,
  IN UCHAR Value);

NTHALAPI
VOID
NTAPI
WRITE_PORT_ULONG(
  IN PULONG Port,
  IN ULONG Value);

NTHALAPI
VOID
NTAPI
WRITE_PORT_USHORT(
  IN PUSHORT Port,
  IN USHORT Value);

NTKERNELAPI
VOID
NTAPI
WRITE_REGISTER_BUFFER_UCHAR(
  IN PUCHAR Register,
  IN PUCHAR Buffer,
  IN ULONG Count);

NTKERNELAPI
VOID
NTAPI
WRITE_REGISTER_BUFFER_ULONG(
  IN PULONG Register,
  IN PULONG Buffer,
  IN ULONG Count);

NTKERNELAPI
VOID
NTAPI
WRITE_REGISTER_BUFFER_USHORT(
  IN PUSHORT Register,
  IN PUSHORT Buffer,
  IN ULONG Count);

NTKERNELAPI
VOID
NTAPI
WRITE_REGISTER_UCHAR(
  IN PUCHAR Register,
  IN UCHAR Value);

NTKERNELAPI
VOID
NTAPI
WRITE_REGISTER_ULONG(
  IN PULONG Register,
  IN ULONG Value);

NTKERNELAPI
VOID
NTAPI
WRITE_REGISTER_USHORT(
  IN PUSHORT Register,
  IN USHORT Value);

#else

FORCEINLINE
VOID
READ_PORT_BUFFER_UCHAR(
  IN PUCHAR Port,
  IN PUCHAR Buffer,
  IN ULONG Count)
{
  __inbytestring((USHORT)(ULONG_PTR)Port, Buffer, Count);
}

FORCEINLINE
VOID
READ_PORT_BUFFER_ULONG(
  IN PULONG Port,
  IN PULONG Buffer,
  IN ULONG Count)
{
  __indwordstring((USHORT)(ULONG_PTR)Port, Buffer, Count);
}

FORCEINLINE
VOID
READ_PORT_BUFFER_USHORT(
  IN PUSHORT Port,
  IN PUSHORT Buffer,
  IN ULONG Count)
{
  __inwordstring((USHORT)(ULONG_PTR)Port, Buffer, Count);
}

FORCEINLINE
UCHAR
READ_PORT_UCHAR(
  IN PUCHAR Port)
{
  return __inbyte((USHORT)(ULONG_PTR)Port);
}

FORCEINLINE
ULONG
READ_PORT_ULONG(
  IN PULONG Port)
{
  return __indword((USHORT)(ULONG_PTR)Port);
}

FORCEINLINE
USHORT
READ_PORT_USHORT(
  IN PUSHORT Port)
{
  return __inword((USHORT)(ULONG_PTR)Port);
}

FORCEINLINE
VOID
READ_REGISTER_BUFFER_UCHAR(
  IN PUCHAR Register,
  IN PUCHAR Buffer,
  IN ULONG Count)
{
  __movsb(Register, Buffer, Count);
}

FORCEINLINE
VOID
READ_REGISTER_BUFFER_ULONG(
  IN PULONG Register,
  IN PULONG Buffer,
  IN ULONG Count)
{
  __movsd(Register, Buffer, Count);
}

FORCEINLINE
VOID
READ_REGISTER_BUFFER_USHORT(
  IN PUSHORT Register,
  IN PUSHORT Buffer,
  IN ULONG Count)
{
  __movsw(Register, Buffer, Count);
}

FORCEINLINE
UCHAR
READ_REGISTER_UCHAR(
  IN volatile UCHAR *Register)
{
  return *Register;
}

FORCEINLINE
ULONG
READ_REGISTER_ULONG(
  IN volatile ULONG *Register)
{
  return *Register;
}

FORCEINLINE
USHORT
READ_REGISTER_USHORT(
  IN volatile USHORT *Register)
{
  return *Register;
}

FORCEINLINE
VOID
WRITE_PORT_BUFFER_UCHAR(
  IN PUCHAR Port,
  IN PUCHAR Buffer,
  IN ULONG Count)
{
  __outbytestring((USHORT)(ULONG_PTR)Port, Buffer, Count);
}

FORCEINLINE
VOID
WRITE_PORT_BUFFER_ULONG(
  IN PULONG Port,
  IN PULONG Buffer,
  IN ULONG Count)
{
  __outdwordstring((USHORT)(ULONG_PTR)Port, Buffer, Count);
}

FORCEINLINE
VOID
WRITE_PORT_BUFFER_USHORT(
  IN PUSHORT Port,
  IN PUSHORT Buffer,
  IN ULONG Count)
{
  __outwordstring((USHORT)(ULONG_PTR)Port, Buffer, Count);
}

FORCEINLINE
VOID
WRITE_PORT_UCHAR(
  IN PUCHAR Port,
  IN UCHAR Value)
{
  __outbyte((USHORT)(ULONG_PTR)Port, Value);
}

FORCEINLINE
VOID
WRITE_PORT_ULONG(
  IN PULONG Port,
  IN ULONG Value)
{
  __outdword((USHORT)(ULONG_PTR)Port, Value);
}

FORCEINLINE
VOID
WRITE_PORT_USHORT(
  IN PUSHORT Port,
  IN USHORT Value)
{
  __outword((USHORT)(ULONG_PTR)Port, Value);
}

FORCEINLINE
VOID
WRITE_REGISTER_BUFFER_UCHAR(
  IN PUCHAR Register,
  IN PUCHAR Buffer,
  IN ULONG Count)
{
  LONG Synch;
  __movsb(Register, Buffer, Count);
  InterlockedOr(&Synch, 1);
}

FORCEINLINE
VOID
WRITE_REGISTER_BUFFER_ULONG(
  IN PULONG Register,
  IN PULONG Buffer,
  IN ULONG Count)
{
  LONG Synch;
  __movsd(Register, Buffer, Count);
  InterlockedOr(&Synch, 1);
}

FORCEINLINE
VOID
WRITE_REGISTER_BUFFER_USHORT(
  IN PUSHORT Register,
  IN PUSHORT Buffer,
  IN ULONG Count)
{
  LONG Synch;
  __movsw(Register, Buffer, Count);
  InterlockedOr(&Synch, 1);
}

FORCEINLINE
VOID
WRITE_REGISTER_UCHAR(
  IN volatile UCHAR *Register,
  IN UCHAR Value)
{
  LONG Synch;
  *Register = Value;
  InterlockedOr(&Synch, 1);
}

FORCEINLINE
VOID
WRITE_REGISTER_ULONG(
  IN volatile ULONG *Register,
  IN ULONG Value)
{
  LONG Synch;
  *Register = Value;
  InterlockedOr(&Synch, 1);
}

FORCEINLINE
VOID
WRITE_REGISTER_USHORT(
  IN volatile USHORT *Register,
  IN USHORT Value)
{
  LONG Sync;
  *Register = Value;
  InterlockedOr(&Sync, 1);
}
#endif

#if defined(USE_DMA_MACROS) && !defined(_NTHAL_) && \
   (defined(_NTDDK_) || defined(_NTDRIVER_)) || defined(_WDM_INCLUDED_)

#define DMA_MACROS_DEFINED

FORCEINLINE
NTSTATUS
IoAllocateAdapterChannel(
  IN PDMA_ADAPTER DmaAdapter,
  IN PDEVICE_OBJECT DeviceObject,
  IN ULONG NumberOfMapRegisters,
  IN PDRIVER_CONTROL ExecutionRoutine,
  IN PVOID Context)
{
  PALLOCATE_ADAPTER_CHANNEL AllocateAdapterChannel;
  AllocateAdapterChannel =
      *(DmaAdapter)->DmaOperations->AllocateAdapterChannel;
  ASSERT(AllocateAdapterChannel);
  return AllocateAdapterChannel(DmaAdapter,
                                DeviceObject,
                                NumberOfMapRegisters,
                                ExecutionRoutine,
                                Context );
}

FORCEINLINE
BOOLEAN
NTAPI
IoFlushAdapterBuffers(
  IN PDMA_ADAPTER DmaAdapter,
  IN PMDL Mdl,
  IN PVOID MapRegisterBase,
  IN PVOID CurrentVa,
  IN ULONG Length,
  IN BOOLEAN WriteToDevice)
{
  PFLUSH_ADAPTER_BUFFERS FlushAdapterBuffers;
  FlushAdapterBuffers = *(DmaAdapter)->DmaOperations->FlushAdapterBuffers;
  ASSERT(FlushAdapterBuffers);
  return FlushAdapterBuffers(DmaAdapter,
                             Mdl,
                             MapRegisterBase,
                             CurrentVa,
                             Length,
                             WriteToDevice);
}

FORCEINLINE
VOID
NTAPI
IoFreeAdapterChannel(
  IN PDMA_ADAPTER DmaAdapter)
{
  PFREE_ADAPTER_CHANNEL FreeAdapterChannel;
  FreeAdapterChannel = *(DmaAdapter)->DmaOperations->FreeAdapterChannel;
  ASSERT(FreeAdapterChannel);
  FreeAdapterChannel(DmaAdapter);
}

FORCEINLINE
VOID
NTAPI
IoFreeMapRegisters(
  IN PDMA_ADAPTER DmaAdapter,
  IN PVOID MapRegisterBase,
  IN ULONG NumberOfMapRegisters)
{
  PFREE_MAP_REGISTERS FreeMapRegisters;
  FreeMapRegisters = *(DmaAdapter)->DmaOperations->FreeMapRegisters;
  ASSERT(FreeMapRegisters);
  FreeMapRegisters(DmaAdapter, MapRegisterBase, NumberOfMapRegisters);
}

FORCEINLINE
PHYSICAL_ADDRESS
NTAPI
IoMapTransfer(
  IN PDMA_ADAPTER DmaAdapter,
  IN PMDL Mdl,
  IN PVOID MapRegisterBase,
  IN PVOID CurrentVa,
  IN OUT PULONG Length,
  IN BOOLEAN WriteToDevice)
{
  PMAP_TRANSFER MapTransfer;

  MapTransfer = *(DmaAdapter)->DmaOperations->MapTransfer;
  ASSERT(MapTransfer);
  return MapTransfer(DmaAdapter,
                     Mdl,
                     MapRegisterBase,
                     CurrentVa,
                     Length,
                     WriteToDevice);
}
#endif

#if (NTDDI_VERSION >= NTDDI_WIN2K)

NTKERNELAPI
VOID
NTAPI
IoAcquireCancelSpinLock(
  OUT PKIRQL Irql);

NTKERNELAPI
NTSTATUS
NTAPI
IoAcquireRemoveLockEx(
  IN PIO_REMOVE_LOCK RemoveLock,
  IN PVOID Tag OPTIONAL,
  IN PCSTR File,
  IN ULONG Line,
  IN ULONG RemlockSize);
NTKERNELAPI
NTSTATUS
NTAPI
IoAllocateDriverObjectExtension(
  IN PDRIVER_OBJECT DriverObject,
  IN PVOID ClientIdentificationAddress,
  IN ULONG DriverObjectExtensionSize,
  OUT PVOID *DriverObjectExtension);

NTKERNELAPI
PVOID
NTAPI
IoAllocateErrorLogEntry(
  IN PVOID IoObject,
  IN UCHAR EntrySize);

NTKERNELAPI
PIRP
NTAPI
IoAllocateIrp(
  IN CCHAR StackSize,
  IN BOOLEAN ChargeQuota);

NTKERNELAPI
PMDL
NTAPI
IoAllocateMdl(
  IN PVOID VirtualAddress OPTIONAL,
  IN ULONG Length,
  IN BOOLEAN SecondaryBuffer,
  IN BOOLEAN ChargeQuota,
  IN OUT PIRP Irp OPTIONAL);

NTKERNELAPI
PIO_WORKITEM
NTAPI
IoAllocateWorkItem(
  IN PDEVICE_OBJECT DeviceObject);

NTKERNELAPI
NTSTATUS
NTAPI
IoAttachDevice(
  IN PDEVICE_OBJECT SourceDevice,
  IN PUNICODE_STRING TargetDevice,
  OUT PDEVICE_OBJECT *AttachedDevice);

NTKERNELAPI
PDEVICE_OBJECT
NTAPI
IoAttachDeviceToDeviceStack(
  IN PDEVICE_OBJECT SourceDevice,
  IN PDEVICE_OBJECT TargetDevice);

NTKERNELAPI
PIRP
NTAPI
IoBuildAsynchronousFsdRequest(
  IN ULONG MajorFunction,
  IN PDEVICE_OBJECT DeviceObject,
  IN OUT PVOID Buffer OPTIONAL,
  IN ULONG Length OPTIONAL,
  IN PLARGE_INTEGER StartingOffset OPTIONAL,
  IN PIO_STATUS_BLOCK IoStatusBlock OPTIONAL);

NTKERNELAPI
PIRP
NTAPI
IoBuildDeviceIoControlRequest(
  IN ULONG IoControlCode,
  IN PDEVICE_OBJECT DeviceObject,
  IN PVOID InputBuffer OPTIONAL,
  IN ULONG InputBufferLength,
  OUT PVOID OutputBuffer OPTIONAL,
  IN ULONG OutputBufferLength,
  IN BOOLEAN InternalDeviceIoControl,
  IN PKEVENT Event,
  OUT PIO_STATUS_BLOCK IoStatusBlock);

NTKERNELAPI
VOID
NTAPI
IoBuildPartialMdl(
  IN PMDL SourceMdl,
  IN OUT PMDL TargetMdl,
  IN PVOID VirtualAddress,
  IN ULONG Length);

NTKERNELAPI
PIRP
NTAPI
IoBuildSynchronousFsdRequest(
  IN ULONG MajorFunction,
  IN PDEVICE_OBJECT DeviceObject,
  IN OUT PVOID Buffer OPTIONAL,
  IN ULONG Length OPTIONAL,
  IN PLARGE_INTEGER StartingOffset OPTIONAL,
  IN PKEVENT Event,
  OUT PIO_STATUS_BLOCK IoStatusBlock);

NTKERNELAPI
NTSTATUS
FASTCALL
IofCallDriver(
  IN PDEVICE_OBJECT DeviceObject,
  IN OUT PIRP Irp);
#define IoCallDriver IofCallDriver

NTKERNELAPI
VOID
FASTCALL
IofCompleteRequest(
  IN PIRP Irp,
  IN CCHAR PriorityBoost);
#define IoCompleteRequest IofCompleteRequest

NTKERNELAPI
BOOLEAN
NTAPI
IoCancelIrp(
  IN PIRP Irp);

NTKERNELAPI
NTSTATUS
NTAPI
IoCheckShareAccess(
  IN ACCESS_MASK DesiredAccess,
  IN ULONG DesiredShareAccess,
  IN OUT PFILE_OBJECT FileObject,
  IN OUT PSHARE_ACCESS ShareAccess,
  IN BOOLEAN Update);

NTKERNELAPI
VOID
FASTCALL
IofCompleteRequest(
  IN PIRP Irp,
  IN CCHAR PriorityBoost);

NTKERNELAPI
NTSTATUS
NTAPI
IoConnectInterrupt(
  OUT PKINTERRUPT *InterruptObject,
  IN PKSERVICE_ROUTINE ServiceRoutine,
  IN PVOID ServiceContext OPTIONAL,
  IN PKSPIN_LOCK SpinLock OPTIONAL,
  IN ULONG Vector,
  IN KIRQL Irql,
  IN KIRQL SynchronizeIrql,
  IN KINTERRUPT_MODE InterruptMode,
  IN BOOLEAN ShareVector,
  IN KAFFINITY ProcessorEnableMask,
  IN BOOLEAN FloatingSave);

NTKERNELAPI
NTSTATUS
NTAPI
IoCreateDevice(
  IN PDRIVER_OBJECT DriverObject,
  IN ULONG DeviceExtensionSize,
  IN PUNICODE_STRING DeviceName OPTIONAL,
  IN DEVICE_TYPE DeviceType,
  IN ULONG DeviceCharacteristics,
  IN BOOLEAN Exclusive,
  OUT PDEVICE_OBJECT *DeviceObject);

NTKERNELAPI
NTSTATUS
NTAPI
IoCreateFile(
  OUT PHANDLE FileHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN PLARGE_INTEGER AllocationSize OPTIONAL,
  IN ULONG FileAttributes,
  IN ULONG ShareAccess,
  IN ULONG Disposition,
  IN ULONG CreateOptions,
  IN PVOID EaBuffer OPTIONAL,
  IN ULONG EaLength,
  IN CREATE_FILE_TYPE CreateFileType,
  IN PVOID InternalParameters OPTIONAL,
  IN ULONG Options);

NTKERNELAPI
PKEVENT
NTAPI
IoCreateNotificationEvent(
  IN PUNICODE_STRING EventName,
  OUT PHANDLE EventHandle);

NTKERNELAPI
NTSTATUS
NTAPI
IoCreateSymbolicLink(
  IN PUNICODE_STRING SymbolicLinkName,
  IN PUNICODE_STRING DeviceName);

NTKERNELAPI
PKEVENT
NTAPI
IoCreateSynchronizationEvent(
  IN PUNICODE_STRING EventName,
  OUT PHANDLE EventHandle);

NTKERNELAPI
NTSTATUS
NTAPI
IoCreateUnprotectedSymbolicLink(
  IN PUNICODE_STRING SymbolicLinkName,
  IN PUNICODE_STRING DeviceName);

NTKERNELAPI
VOID
NTAPI
IoDeleteDevice(
  IN PDEVICE_OBJECT DeviceObject);

NTKERNELAPI
NTSTATUS
NTAPI
IoDeleteSymbolicLink(
  IN PUNICODE_STRING SymbolicLinkName);

NTKERNELAPI
VOID
NTAPI
IoDetachDevice(
  IN OUT PDEVICE_OBJECT TargetDevice);

NTKERNELAPI
VOID
NTAPI
IoDisconnectInterrupt(
  IN PKINTERRUPT InterruptObject);

NTKERNELAPI
VOID
NTAPI
IoFreeIrp(
  IN PIRP Irp);

NTKERNELAPI
VOID
NTAPI
IoFreeMdl(
  IN PMDL Mdl);

NTKERNELAPI
VOID
NTAPI
IoFreeWorkItem(
  IN PIO_WORKITEM IoWorkItem);

NTKERNELAPI
PDEVICE_OBJECT
NTAPI
IoGetAttachedDevice(
  IN PDEVICE_OBJECT DeviceObject);

NTKERNELAPI
PDEVICE_OBJECT
NTAPI
IoGetAttachedDeviceReference(
  IN PDEVICE_OBJECT DeviceObject);

NTKERNELAPI
NTSTATUS
NTAPI
IoGetBootDiskInformation(
  IN OUT PBOOTDISK_INFORMATION BootDiskInformation,
  IN ULONG Size);

NTKERNELAPI
NTSTATUS
NTAPI
IoGetDeviceInterfaceAlias(
  IN PUNICODE_STRING SymbolicLinkName,
  IN CONST GUID *AliasInterfaceClassGuid,
  OUT PUNICODE_STRING AliasSymbolicLinkName);

NTKERNELAPI
PEPROCESS
NTAPI
IoGetCurrentProcess(VOID);

NTKERNELAPI
NTSTATUS
NTAPI
IoGetDeviceInterfaces(
  IN CONST GUID *InterfaceClassGuid,
  IN PDEVICE_OBJECT PhysicalDeviceObject OPTIONAL,
  IN ULONG Flags,
  OUT PWSTR *SymbolicLinkList);

NTKERNELAPI
NTSTATUS
NTAPI
IoGetDeviceObjectPointer(
  IN PUNICODE_STRING ObjectName,
  IN ACCESS_MASK DesiredAccess,
  OUT PFILE_OBJECT *FileObject,
  OUT PDEVICE_OBJECT *DeviceObject);

NTKERNELAPI
NTSTATUS
NTAPI
IoGetDeviceProperty(
  IN PDEVICE_OBJECT DeviceObject,
  IN DEVICE_REGISTRY_PROPERTY DeviceProperty,
  IN ULONG BufferLength,
  OUT PVOID PropertyBuffer,
  OUT PULONG ResultLength);

NTKERNELAPI
PDMA_ADAPTER
NTAPI
IoGetDmaAdapter(
  IN PDEVICE_OBJECT PhysicalDeviceObject OPTIONAL,
  IN PDEVICE_DESCRIPTION DeviceDescription,
  IN OUT PULONG NumberOfMapRegisters);

NTKERNELAPI
PVOID
NTAPI
IoGetDriverObjectExtension(
  IN PDRIVER_OBJECT DriverObject,
  IN PVOID ClientIdentificationAddress);

NTKERNELAPI
PVOID
NTAPI
IoGetInitialStack(VOID);

NTKERNELAPI
PDEVICE_OBJECT
NTAPI
IoGetRelatedDeviceObject(
  IN PFILE_OBJECT FileObject);

NTKERNELAPI
VOID
NTAPI
IoQueueWorkItem(
  IN PIO_WORKITEM IoWorkItem,
  IN PIO_WORKITEM_ROUTINE WorkerRoutine,
  IN WORK_QUEUE_TYPE QueueType,
  IN PVOID Context OPTIONAL);

NTKERNELAPI
VOID
NTAPI
IoInitializeIrp(
  IN OUT PIRP Irp,
  IN USHORT PacketSize,
  IN CCHAR StackSize);

NTKERNELAPI
VOID
NTAPI
IoInitializeRemoveLockEx(
  IN PIO_REMOVE_LOCK Lock,
  IN ULONG AllocateTag,
  IN ULONG MaxLockedMinutes,
  IN ULONG HighWatermark,
  IN ULONG RemlockSize);

NTKERNELAPI
NTSTATUS
NTAPI
IoInitializeTimer(
  IN PDEVICE_OBJECT DeviceObject,
  IN PIO_TIMER_ROUTINE TimerRoutine,
  IN PVOID Context OPTIONAL);

NTKERNELAPI
VOID
NTAPI
IoInvalidateDeviceRelations(
  IN PDEVICE_OBJECT DeviceObject,
  IN DEVICE_RELATION_TYPE Type);

NTKERNELAPI
VOID
NTAPI
IoInvalidateDeviceState(
  IN PDEVICE_OBJECT PhysicalDeviceObject);

NTKERNELAPI
BOOLEAN
NTAPI
IoIsWdmVersionAvailable(
  IN UCHAR MajorVersion,
  IN UCHAR MinorVersion);

NTKERNELAPI
NTSTATUS
NTAPI
IoOpenDeviceInterfaceRegistryKey(
  IN PUNICODE_STRING SymbolicLinkName,
  IN ACCESS_MASK DesiredAccess,
  OUT PHANDLE DeviceInterfaceKey);

NTKERNELAPI
NTSTATUS
NTAPI
IoOpenDeviceRegistryKey(
  IN PDEVICE_OBJECT DeviceObject,
  IN ULONG DevInstKeyType,
  IN ACCESS_MASK DesiredAccess,
  OUT PHANDLE DevInstRegKey);

NTKERNELAPI
NTSTATUS
NTAPI
IoRegisterDeviceInterface(
  IN PDEVICE_OBJECT PhysicalDeviceObject,
  IN CONST GUID *InterfaceClassGuid,
  IN PUNICODE_STRING ReferenceString OPTIONAL,
  OUT PUNICODE_STRING SymbolicLinkName);

NTKERNELAPI
NTSTATUS
NTAPI
IoRegisterPlugPlayNotification(
  IN IO_NOTIFICATION_EVENT_CATEGORY EventCategory,
  IN ULONG EventCategoryFlags,
  IN PVOID EventCategoryData OPTIONAL,
  IN PDRIVER_OBJECT DriverObject,
  IN PDRIVER_NOTIFICATION_CALLBACK_ROUTINE CallbackRoutine,
  IN OUT PVOID Context OPTIONAL,
  OUT PVOID *NotificationEntry);

NTKERNELAPI
NTSTATUS
NTAPI
IoRegisterShutdownNotification(
  IN PDEVICE_OBJECT DeviceObject);

NTKERNELAPI
VOID
NTAPI
IoReleaseCancelSpinLock(
  IN KIRQL Irql);

NTKERNELAPI
VOID
NTAPI
IoReleaseRemoveLockAndWaitEx(
  IN PIO_REMOVE_LOCK RemoveLock,
  IN PVOID Tag OPTIONAL,
  IN ULONG RemlockSize);

NTKERNELAPI
VOID
NTAPI
IoReleaseRemoveLockEx(
  IN PIO_REMOVE_LOCK RemoveLock,
  IN PVOID Tag OPTIONAL,
  IN ULONG RemlockSize);

NTKERNELAPI
VOID
NTAPI
IoRemoveShareAccess(
  IN PFILE_OBJECT FileObject,
  IN OUT PSHARE_ACCESS ShareAccess);

NTKERNELAPI
NTSTATUS
NTAPI
IoReportTargetDeviceChange(
  IN PDEVICE_OBJECT PhysicalDeviceObject,
  IN PVOID NotificationStructure);

NTKERNELAPI
NTSTATUS
NTAPI
IoReportTargetDeviceChangeAsynchronous(
  IN PDEVICE_OBJECT PhysicalDeviceObject,
  IN PVOID NotificationStructure,
  IN PDEVICE_CHANGE_COMPLETE_CALLBACK Callback OPTIONAL,
  IN PVOID Context OPTIONAL);

NTKERNELAPI
VOID
NTAPI
IoRequestDeviceEject(
  IN PDEVICE_OBJECT PhysicalDeviceObject);

NTKERNELAPI
VOID
NTAPI
IoReuseIrp(
  IN OUT PIRP Irp,
  IN NTSTATUS Status);

NTKERNELAPI
NTSTATUS
NTAPI
IoSetDeviceInterfaceState(
  IN PUNICODE_STRING SymbolicLinkName,
  IN BOOLEAN Enable);

NTKERNELAPI
VOID
NTAPI
IoSetShareAccess(
  IN ACCESS_MASK DesiredAccess,
  IN ULONG DesiredShareAccess,
  IN OUT PFILE_OBJECT FileObject,
  OUT PSHARE_ACCESS ShareAccess);

NTKERNELAPI
VOID
NTAPI
IoStartNextPacket(
  IN PDEVICE_OBJECT DeviceObject,
  IN BOOLEAN Cancelable);

NTKERNELAPI
VOID
NTAPI
IoStartNextPacketByKey(
  IN PDEVICE_OBJECT DeviceObject,
  IN BOOLEAN Cancelable,
  IN ULONG Key);

NTKERNELAPI
VOID
NTAPI
IoStartPacket(
  IN PDEVICE_OBJECT DeviceObject,
  IN PIRP Irp,
  IN PULONG Key OPTIONAL,
  IN PDRIVER_CANCEL CancelFunction OPTIONAL);

NTKERNELAPI
VOID
NTAPI
IoStartTimer(
  IN PDEVICE_OBJECT DeviceObject);

NTKERNELAPI
VOID
NTAPI
IoStopTimer(
  IN PDEVICE_OBJECT DeviceObject);

NTKERNELAPI
NTSTATUS
NTAPI
IoUnregisterPlugPlayNotification(
  IN PVOID NotificationEntry);

NTKERNELAPI
VOID
NTAPI
IoUnregisterShutdownNotification(
  IN PDEVICE_OBJECT DeviceObject);

NTKERNELAPI
VOID
NTAPI
IoUpdateShareAccess(
  IN PFILE_OBJECT FileObject,
  IN OUT PSHARE_ACCESS ShareAccess);

NTKERNELAPI
NTSTATUS
NTAPI
IoWMIAllocateInstanceIds(
  IN GUID *Guid,
  IN ULONG InstanceCount,
  OUT ULONG *FirstInstanceId);

NTKERNELAPI
NTSTATUS
NTAPI
IoWMIQuerySingleInstanceMultiple(
  IN PVOID *DataBlockObjectList,
  IN PUNICODE_STRING InstanceNames,
  IN ULONG ObjectCount,
  IN OUT ULONG *InOutBufferSize,
  OUT PVOID OutBuffer);

NTKERNELAPI
NTSTATUS
NTAPI
IoWMIRegistrationControl(
  IN PDEVICE_OBJECT DeviceObject,
  IN ULONG Action);

NTKERNELAPI
NTSTATUS
NTAPI
IoWMISuggestInstanceName(
  IN PDEVICE_OBJECT PhysicalDeviceObject OPTIONAL,
  IN PUNICODE_STRING SymbolicLinkName OPTIONAL,
  IN BOOLEAN CombineNames,
  OUT PUNICODE_STRING SuggestedInstanceName);

NTKERNELAPI
NTSTATUS
NTAPI
IoWMIWriteEvent(
  IN OUT PVOID WnodeEventItem);

NTKERNELAPI
VOID
NTAPI
IoWriteErrorLogEntry(
  IN PVOID ElEntry);

NTKERNELAPI
PIRP
NTAPI
IoGetTopLevelIrp(VOID);

NTKERNELAPI
NTSTATUS
NTAPI
IoRegisterLastChanceShutdownNotification(
  IN PDEVICE_OBJECT DeviceObject);

NTKERNELAPI
VOID
NTAPI
IoSetTopLevelIrp(
  IN PIRP Irp OPTIONAL);

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */


#if (NTDDI_VERSION >= NTDDI_WINXP)

NTKERNELAPI
NTSTATUS
NTAPI
IoCsqInitialize(
  IN PIO_CSQ Csq,
  IN PIO_CSQ_INSERT_IRP CsqInsertIrp,
  IN PIO_CSQ_REMOVE_IRP CsqRemoveIrp,
  IN PIO_CSQ_PEEK_NEXT_IRP CsqPeekNextIrp,
  IN PIO_CSQ_ACQUIRE_LOCK CsqAcquireLock,
  IN PIO_CSQ_RELEASE_LOCK CsqReleaseLock,
  IN PIO_CSQ_COMPLETE_CANCELED_IRP CsqCompleteCanceledIrp);

NTKERNELAPI
VOID
NTAPI
IoCsqInsertIrp(
  IN PIO_CSQ Csq,
  IN PIRP Irp,
  IN PIO_CSQ_IRP_CONTEXT Context OPTIONAL);

NTKERNELAPI
PIRP
NTAPI
IoCsqRemoveIrp(
  IN PIO_CSQ Csq,
  IN PIO_CSQ_IRP_CONTEXT Context);

NTKERNELAPI
PIRP
NTAPI
IoCsqRemoveNextIrp(
  IN PIO_CSQ Csq,
  IN PVOID PeekContext OPTIONAL);

NTKERNELAPI
BOOLEAN
NTAPI
IoForwardIrpSynchronously(
  IN PDEVICE_OBJECT DeviceObject,
  IN PIRP Irp);

#define IoForwardAndCatchIrp IoForwardIrpSynchronously

NTKERNELAPI
VOID
NTAPI
IoFreeErrorLogEntry(
  PVOID ElEntry);

NTKERNELAPI
NTSTATUS
NTAPI
IoSetCompletionRoutineEx(
  IN PDEVICE_OBJECT DeviceObject,
  IN PIRP Irp,
  IN PIO_COMPLETION_ROUTINE CompletionRoutine,
  IN PVOID Context,
  IN BOOLEAN InvokeOnSuccess,
  IN BOOLEAN InvokeOnError,
  IN BOOLEAN InvokeOnCancel);

VOID
NTAPI
IoSetStartIoAttributes(
  IN PDEVICE_OBJECT DeviceObject,
  IN BOOLEAN DeferredStartIo,
  IN BOOLEAN NonCancelable);

NTKERNELAPI
NTSTATUS
NTAPI
IoWMIDeviceObjectToInstanceName(
  IN PVOID DataBlockObject,
  IN PDEVICE_OBJECT DeviceObject,
  OUT PUNICODE_STRING InstanceName);

NTKERNELAPI
NTSTATUS
NTAPI
IoWMIExecuteMethod(
  IN PVOID DataBlockObject,
  IN PUNICODE_STRING InstanceName,
  IN ULONG MethodId,
  IN ULONG InBufferSize,
  IN OUT PULONG OutBufferSize,
  IN OUT  PUCHAR InOutBuffer);

NTKERNELAPI
NTSTATUS
NTAPI
IoWMIHandleToInstanceName(
  IN PVOID DataBlockObject,
  IN HANDLE FileHandle,
  OUT PUNICODE_STRING InstanceName);

NTKERNELAPI
NTSTATUS
NTAPI
IoWMIOpenBlock(
  IN GUID *DataBlockGuid,
  IN ULONG DesiredAccess,
  OUT PVOID *DataBlockObject);

NTKERNELAPI
NTSTATUS
NTAPI
IoWMIQueryAllData(
  IN PVOID DataBlockObject,
  IN OUT ULONG *InOutBufferSize,
  OUT PVOID OutBuffer);

NTKERNELAPI
NTSTATUS
NTAPI
IoWMIQueryAllDataMultiple(
  IN PVOID *DataBlockObjectList,
  IN ULONG ObjectCount,
  IN OUT ULONG *InOutBufferSize,
  OUT PVOID OutBuffer);

NTKERNELAPI
NTSTATUS
NTAPI
IoWMIQuerySingleInstance(
  IN PVOID DataBlockObject,
  IN PUNICODE_STRING InstanceName,
  IN OUT ULONG *InOutBufferSize,
  OUT PVOID OutBuffer);

NTKERNELAPI
NTSTATUS
NTAPI
IoWMISetNotificationCallback(
  IN OUT PVOID Object,
  IN WMI_NOTIFICATION_CALLBACK Callback,
  IN PVOID Context OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
IoWMISetSingleInstance(
  IN PVOID DataBlockObject,
  IN PUNICODE_STRING InstanceName,
  IN ULONG Version,
  IN ULONG ValueBufferSize,
  IN PVOID ValueBuffer);

NTKERNELAPI
NTSTATUS
NTAPI
IoWMISetSingleItem(
  IN PVOID DataBlockObject,
  IN PUNICODE_STRING InstanceName,
  IN ULONG DataItemId,
  IN ULONG Version,
  IN ULONG ValueBufferSize,
  IN PVOID ValueBuffer);

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

#if (NTDDI_VERSION >= NTDDI_WINXPSP1)
NTKERNELAPI
NTSTATUS
NTAPI
IoValidateDeviceIoControlAccess(
  IN PIRP Irp,
  IN ULONG RequiredAccess);
#endif

#if (NTDDI_VERSION >= NTDDI_WS03)
NTKERNELAPI
NTSTATUS
NTAPI
IoCsqInitializeEx(
  IN PIO_CSQ Csq,
  IN PIO_CSQ_INSERT_IRP_EX CsqInsertIrp,
  IN PIO_CSQ_REMOVE_IRP CsqRemoveIrp,
  IN PIO_CSQ_PEEK_NEXT_IRP CsqPeekNextIrp,
  IN PIO_CSQ_ACQUIRE_LOCK CsqAcquireLock,
  IN PIO_CSQ_RELEASE_LOCK CsqReleaseLock,
  IN PIO_CSQ_COMPLETE_CANCELED_IRP CsqCompleteCanceledIrp);

NTKERNELAPI
NTSTATUS
NTAPI
IoCsqInsertIrpEx(
  IN PIO_CSQ Csq,
  IN PIRP Irp,
  IN PIO_CSQ_IRP_CONTEXT Context OPTIONAL,
  IN PVOID InsertContext OPTIONAL);
#endif /* (NTDDI_VERSION >= NTDDI_WS03) */


#if (NTDDI_VERSION >= NTDDI_VISTA)
NTKERNELAPI
NTSTATUS
NTAPI
IoGetBootDiskInformationLite(
  OUT PBOOTDISK_INFORMATION_LITE *BootDiskInformation);

NTKERNELAPI
NTSTATUS
NTAPI
IoCheckShareAccessEx(
  IN ACCESS_MASK DesiredAccess,
  IN ULONG DesiredShareAccess,
  IN OUT PFILE_OBJECT FileObject,
  IN OUT PSHARE_ACCESS ShareAccess,
  IN BOOLEAN Update,
  IN PBOOLEAN WritePermission);

NTKERNELAPI
NTSTATUS
NTAPI
IoConnectInterruptEx(
  IN OUT PIO_CONNECT_INTERRUPT_PARAMETERS Parameters);

NTKERNELAPI
VOID
NTAPI
IoDisconnectInterruptEx(
  IN PIO_DISCONNECT_INTERRUPT_PARAMETERS Parameters);

LOGICAL
NTAPI
IoWithinStackLimits(
  IN ULONG_PTR RegionStart,
  IN SIZE_T RegionSize);

NTKERNELAPI
VOID
NTAPI
IoSetShareAccessEx(
  IN ACCESS_MASK DesiredAccess,
  IN ULONG DesiredShareAccess,
  IN OUT PFILE_OBJECT FileObject,
  OUT PSHARE_ACCESS ShareAccess,
  IN PBOOLEAN WritePermission);

ULONG
NTAPI
IoSizeofWorkItem(VOID);

VOID
NTAPI
IoInitializeWorkItem(
  IN PVOID IoObject,
  IN PIO_WORKITEM IoWorkItem);

VOID
NTAPI
IoUninitializeWorkItem(
  IN PIO_WORKITEM IoWorkItem);

VOID
NTAPI
IoQueueWorkItemEx(
  IN PIO_WORKITEM IoWorkItem,
  IN PIO_WORKITEM_ROUTINE_EX WorkerRoutine,
  IN WORK_QUEUE_TYPE QueueType,
  IN PVOID Context OPTIONAL);

IO_PRIORITY_HINT
NTAPI
IoGetIoPriorityHint(
  IN PIRP Irp);

NTSTATUS
NTAPI
IoSetIoPriorityHint(
  IN PIRP Irp,
  IN IO_PRIORITY_HINT PriorityHint);

NTSTATUS
NTAPI
IoAllocateSfioStreamIdentifier(
  IN PFILE_OBJECT FileObject,
  IN ULONG Length,
  IN PVOID Signature,
  OUT PVOID *StreamIdentifier);

PVOID
NTAPI
IoGetSfioStreamIdentifier(
  IN PFILE_OBJECT FileObject,
  IN PVOID Signature);

NTSTATUS
NTAPI
IoFreeSfioStreamIdentifier(
  IN PFILE_OBJECT FileObject,
  IN PVOID Signature);

NTKERNELAPI
NTSTATUS
NTAPI
IoRequestDeviceEjectEx(
  IN PDEVICE_OBJECT PhysicalDeviceObject,
  IN PIO_DEVICE_EJECT_CALLBACK Callback OPTIONAL,
  IN PVOID Context OPTIONAL,
  IN PDRIVER_OBJECT DriverObject OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
IoSetDevicePropertyData(
  IN PDEVICE_OBJECT     Pdo,
  IN CONST DEVPROPKEY   *PropertyKey,
  IN LCID               Lcid,
  IN ULONG              Flags,
  IN DEVPROPTYPE        Type,
  IN ULONG              Size,
  IN PVOID          Data OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
IoGetDevicePropertyData(
  PDEVICE_OBJECT Pdo,
  CONST DEVPROPKEY *PropertyKey,
  LCID Lcid,
  ULONG Flags,
  ULONG Size,
  PVOID Data,
  PULONG RequiredSize,
  PDEVPROPTYPE Type);

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#define IoCallDriverStackSafeDefault(a, b) IoCallDriver(a, b)

#if (NTDDI_VERSION >= NTDDI_WS08)
NTKERNELAPI
NTSTATUS
NTAPI
IoReplacePartitionUnit(
  IN PDEVICE_OBJECT TargetPdo,
  IN PDEVICE_OBJECT SparePdo,
  IN ULONG Flags);
#endif

#if (NTDDI_VERSION >= NTDDI_WIN7)

NTKERNELAPI
NTSTATUS
NTAPI
IoGetAffinityInterrupt(
  IN PKINTERRUPT InterruptObject,
  OUT PGROUP_AFFINITY GroupAffinity);

NTSTATUS
NTAPI
IoGetContainerInformation(
  IN IO_CONTAINER_INFORMATION_CLASS InformationClass,
  IN PVOID ContainerObject OPTIONAL,
  IN OUT PVOID Buffer OPTIONAL,
  IN ULONG BufferLength);

NTSTATUS
NTAPI
IoRegisterContainerNotification(
  IN IO_CONTAINER_NOTIFICATION_CLASS NotificationClass,
  IN PIO_CONTAINER_NOTIFICATION_FUNCTION CallbackFunction,
  IN PVOID NotificationInformation OPTIONAL,
  IN ULONG NotificationInformationLength,
  OUT PVOID CallbackRegistration);

VOID
NTAPI
IoUnregisterContainerNotification(
  IN PVOID CallbackRegistration);

NTKERNELAPI
NTSTATUS
NTAPI
IoUnregisterPlugPlayNotificationEx(
  IN PVOID NotificationEntry);

NTKERNELAPI
NTSTATUS
NTAPI
IoGetDeviceNumaNode(
  IN PDEVICE_OBJECT Pdo,
  OUT PUSHORT NodeNumber);

#endif /* (NTDDI_VERSION >= NTDDI_WIN7) */

#if defined(_WIN64)
NTKERNELAPI
ULONG
NTAPI
IoWMIDeviceObjectToProviderId(
  IN PDEVICE_OBJECT DeviceObject);
#else
#define IoWMIDeviceObjectToProviderId(DeviceObject) ((ULONG)(DeviceObject))
#endif

/*
 * USHORT
 * IoSizeOfIrp(
 *   IN CCHAR  StackSize)
 */
#define IoSizeOfIrp(_StackSize) \
  ((USHORT) (sizeof(IRP) + ((_StackSize) * (sizeof(IO_STACK_LOCATION)))))

FORCEINLINE
VOID
IoSkipCurrentIrpStackLocation(
  IN OUT PIRP Irp)
{
  ASSERT(Irp->CurrentLocation <= Irp->StackCount);
  Irp->CurrentLocation++;
#ifdef NONAMELESSUNION
  Irp->Tail.Overlay.s.u.CurrentStackLocation++;
#else
  Irp->Tail.Overlay.CurrentStackLocation++;
#endif
}

FORCEINLINE
VOID
IoSetNextIrpStackLocation(
  IN OUT PIRP Irp)
{
  ASSERT(Irp->CurrentLocation > 0);
  Irp->CurrentLocation--;
#ifdef NONAMELESSUNION
  Irp->Tail.Overlay.s.u.CurrentStackLocation--;
#else
  Irp->Tail.Overlay.CurrentStackLocation--;
#endif
}

FORCEINLINE
PIO_STACK_LOCATION
IoGetNextIrpStackLocation(
  IN PIRP Irp)
{
  ASSERT(Irp->CurrentLocation > 0);
#ifdef NONAMELESSUNION
  return ((Irp)->Tail.Overlay.s.u.CurrentStackLocation - 1 );
#else
  return ((Irp)->Tail.Overlay.CurrentStackLocation - 1 );
#endif
}

FORCEINLINE
VOID
IoSetCompletionRoutine(
  IN PIRP Irp,
  IN PIO_COMPLETION_ROUTINE CompletionRoutine OPTIONAL,
  IN PVOID Context OPTIONAL,
  IN BOOLEAN InvokeOnSuccess,
  IN BOOLEAN InvokeOnError,
  IN BOOLEAN InvokeOnCancel)
{
  PIO_STACK_LOCATION irpSp;
  ASSERT( (InvokeOnSuccess || InvokeOnError || InvokeOnCancel) ? (CompletionRoutine != NULL) : TRUE );
  irpSp = IoGetNextIrpStackLocation(Irp);
  irpSp->CompletionRoutine = CompletionRoutine;
  irpSp->Context = Context;
  irpSp->Control = 0;

  if (InvokeOnSuccess) {
    irpSp->Control = SL_INVOKE_ON_SUCCESS;
  }

  if (InvokeOnError) {
    irpSp->Control |= SL_INVOKE_ON_ERROR;
  }

  if (InvokeOnCancel) {
    irpSp->Control |= SL_INVOKE_ON_CANCEL;
  }
}

/*
 * PDRIVER_CANCEL
 * IoSetCancelRoutine(
 *   IN PIRP  Irp,
 *   IN PDRIVER_CANCEL  CancelRoutine)
 */
#define IoSetCancelRoutine(_Irp, \
                           _CancelRoutine) \
  ((PDRIVER_CANCEL) (ULONG_PTR) InterlockedExchangePointer( \
    (PVOID *) &(_Irp)->CancelRoutine, (PVOID) (ULONG_PTR) (_CancelRoutine)))

/*
 * VOID
 * IoRequestDpc(
 *   IN PDEVICE_OBJECT  DeviceObject,
 *   IN PIRP  Irp,
 *   IN PVOID  Context);
 */
#define IoRequestDpc(DeviceObject, Irp, Context)( \
  KeInsertQueueDpc(&(DeviceObject)->Dpc, (Irp), (Context)))

/*
 * VOID
 * IoReleaseRemoveLock(
 *   IN PIO_REMOVE_LOCK  RemoveLock,
 *   IN PVOID  Tag)
 */
#define IoReleaseRemoveLock(_RemoveLock, \
                            _Tag) \
  IoReleaseRemoveLockEx(_RemoveLock, _Tag, sizeof(IO_REMOVE_LOCK))

/*
 * VOID
 * IoReleaseRemoveLockAndWait(
 *   IN PIO_REMOVE_LOCK  RemoveLock,
 *   IN PVOID  Tag)
 */
#define IoReleaseRemoveLockAndWait(_RemoveLock, \
                                   _Tag) \
  IoReleaseRemoveLockAndWaitEx(_RemoveLock, _Tag, sizeof(IO_REMOVE_LOCK))

#if defined(_WIN64)
NTKERNELAPI
BOOLEAN
IoIs32bitProcess(
  IN PIRP Irp OPTIONAL);
#endif

#define PLUGPLAY_REGKEY_DEVICE                            1
#define PLUGPLAY_REGKEY_DRIVER                            2
#define PLUGPLAY_REGKEY_CURRENT_HWPROFILE                 4

FORCEINLINE
PIO_STACK_LOCATION
IoGetCurrentIrpStackLocation(
  IN PIRP Irp)
{
  ASSERT(Irp->CurrentLocation <= Irp->StackCount + 1);
#ifdef NONAMELESSUNION
  return Irp->Tail.Overlay.s.u.CurrentStackLocation;
#else
  return Irp->Tail.Overlay.CurrentStackLocation;
#endif
}

FORCEINLINE
VOID
IoMarkIrpPending(
  IN OUT PIRP Irp)
{
  IoGetCurrentIrpStackLocation( (Irp) )->Control |= SL_PENDING_RETURNED;
}

/*
 * BOOLEAN
 * IoIsErrorUserInduced(
 *   IN NTSTATUS  Status);
 */
#define IoIsErrorUserInduced(Status) \
   ((BOOLEAN)(((Status) == STATUS_DEVICE_NOT_READY) || \
   ((Status) == STATUS_IO_TIMEOUT) || \
   ((Status) == STATUS_MEDIA_WRITE_PROTECTED) || \
   ((Status) == STATUS_NO_MEDIA_IN_DEVICE) || \
   ((Status) == STATUS_VERIFY_REQUIRED) || \
   ((Status) == STATUS_UNRECOGNIZED_MEDIA) || \
   ((Status) == STATUS_WRONG_VOLUME)))

/* VOID
 * IoInitializeRemoveLock(
 *   IN PIO_REMOVE_LOCK  Lock,
 *   IN ULONG  AllocateTag,
 *   IN ULONG  MaxLockedMinutes,
 *   IN ULONG  HighWatermark)
 */
#define IoInitializeRemoveLock( \
  Lock, AllocateTag, MaxLockedMinutes, HighWatermark) \
  IoInitializeRemoveLockEx(Lock, AllocateTag, MaxLockedMinutes, \
    HighWatermark, sizeof(IO_REMOVE_LOCK))

FORCEINLINE
VOID
IoInitializeDpcRequest(
  IN PDEVICE_OBJECT DeviceObject,
  IN PIO_DPC_ROUTINE DpcRoutine)
{
  KeInitializeDpc( &DeviceObject->Dpc,
                   (PKDEFERRED_ROUTINE) DpcRoutine,
                   DeviceObject );
}

#define DEVICE_INTERFACE_INCLUDE_NONACTIVE 0x00000001

/*
 * ULONG
 * IoGetFunctionCodeFromCtlCode(
 *   IN ULONG  ControlCode)
 */
#define IoGetFunctionCodeFromCtlCode(_ControlCode) \
  (((_ControlCode) >> 2) & 0x00000FFF)

FORCEINLINE
VOID
IoCopyCurrentIrpStackLocationToNext(
  IN OUT PIRP Irp)
{
  PIO_STACK_LOCATION irpSp;
  PIO_STACK_LOCATION nextIrpSp;
  irpSp = IoGetCurrentIrpStackLocation(Irp);
  nextIrpSp = IoGetNextIrpStackLocation(Irp);
  RtlCopyMemory( nextIrpSp, irpSp, FIELD_OFFSET(IO_STACK_LOCATION, CompletionRoutine));
  nextIrpSp->Control = 0;
}

NTKERNELAPI
VOID
NTAPI
IoGetStackLimits(
  OUT PULONG_PTR LowLimit,
  OUT PULONG_PTR HighLimit);

FORCEINLINE
ULONG_PTR
IoGetRemainingStackSize(VOID)
{
  ULONG_PTR End, Begin;
  ULONG_PTR Result;

  IoGetStackLimits(&Begin, &End);
  Result = (ULONG_PTR)(&End) - Begin;
  return Result;
}

#if (NTDDI_VERSION >= NTDDI_WS03)
FORCEINLINE
VOID
IoInitializeThreadedDpcRequest(
  IN PDEVICE_OBJECT DeviceObject,
  IN PIO_DPC_ROUTINE DpcRoutine)
{
  KeInitializeThreadedDpc(&DeviceObject->Dpc,
                          (PKDEFERRED_ROUTINE) DpcRoutine,
                          DeviceObject );
}
#endif

/******************************************************************************
 *                     Power Management Support Functions                     *
 ******************************************************************************/

#define PoSetDeviceBusy(IdlePointer) ((void)(*(IdlePointer) = 0))

#if (NTDDI_VERSION >= NTDDI_WIN2K)

NTKERNELAPI
NTSTATUS
NTAPI
PoCallDriver(
  IN struct _DEVICE_OBJECT *DeviceObject,
  IN OUT struct _IRP *Irp);

NTKERNELAPI
PULONG
NTAPI
PoRegisterDeviceForIdleDetection(
  IN struct _DEVICE_OBJECT *DeviceObject,
  IN ULONG ConservationIdleTime,
  IN ULONG PerformanceIdleTime,
  IN DEVICE_POWER_STATE State);

NTKERNELAPI
PVOID
NTAPI
PoRegisterSystemState(
  IN OUT PVOID StateHandle OPTIONAL,
  IN EXECUTION_STATE Flags);

NTKERNELAPI
NTSTATUS
NTAPI
PoRequestPowerIrp(
  IN struct _DEVICE_OBJECT *DeviceObject,
  IN UCHAR MinorFunction,
  IN POWER_STATE PowerState,
  IN PREQUEST_POWER_COMPLETE CompletionFunction OPTIONAL,
  IN PVOID Context OPTIONAL,
  OUT struct _IRP **Irp OPTIONAL);

NTKERNELAPI
POWER_STATE
NTAPI
PoSetPowerState(
  IN struct _DEVICE_OBJECT *DeviceObject,
  IN POWER_STATE_TYPE Type,
  IN POWER_STATE State);

NTKERNELAPI
VOID
NTAPI
PoSetSystemState(
  IN EXECUTION_STATE Flags);

NTKERNELAPI
VOID
NTAPI
PoStartNextPowerIrp(
  IN OUT struct _IRP *Irp);

NTKERNELAPI
VOID
NTAPI
PoUnregisterSystemState(
  IN OUT PVOID StateHandle);

NTKERNELAPI
NTSTATUS
NTAPI
PoRequestShutdownEvent(
  OUT PVOID *Event);

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#if (NTDDI_VERSION >= NTDDI_VISTA)

NTKERNELAPI
VOID
NTAPI
PoSetSystemWake(
  IN OUT struct _IRP *Irp);

NTKERNELAPI
BOOLEAN
NTAPI
PoGetSystemWake(
  IN struct _IRP *Irp);

NTKERNELAPI
NTSTATUS
NTAPI
PoRegisterPowerSettingCallback(
  IN PDEVICE_OBJECT DeviceObject OPTIONAL,
  IN LPCGUID SettingGuid,
  IN PPOWER_SETTING_CALLBACK Callback,
  IN PVOID Context OPTIONAL,
  OUT PVOID *Handle OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
PoUnregisterPowerSettingCallback(
  IN OUT PVOID Handle);

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#if (NTDDI_VERSION >= NTDDI_VISTASP1)
NTKERNELAPI
VOID
NTAPI
PoSetDeviceBusyEx(
  IN OUT PULONG IdlePointer);
#endif /* (NTDDI_VERSION >= NTDDI_VISTASP1) */

#if (NTDDI_VERSION >= NTDDI_WIN7)

NTKERNELAPI
VOID
NTAPI
PoStartDeviceBusy(
  IN OUT PULONG IdlePointer);

NTKERNELAPI
VOID
NTAPI
PoEndDeviceBusy(
  IN OUT PULONG IdlePointer);

NTKERNELAPI
BOOLEAN
NTAPI
PoQueryWatchdogTime(
  IN PDEVICE_OBJECT Pdo,
  OUT PULONG SecondsRemaining);

NTKERNELAPI
VOID
NTAPI
PoDeletePowerRequest(
  IN OUT PVOID PowerRequest);

NTKERNELAPI
NTSTATUS
NTAPI
PoSetPowerRequest(
  IN OUT PVOID PowerRequest,
  IN POWER_REQUEST_TYPE Type);

NTKERNELAPI
NTSTATUS
NTAPI
PoClearPowerRequest(
  IN OUT PVOID PowerRequest,
  IN POWER_REQUEST_TYPE Type);

NTKERNELAPI
NTSTATUS
NTAPI
PoCreatePowerRequest(
  OUT PVOID *PowerRequest,
  IN PDEVICE_OBJECT DeviceObject,
  IN PCOUNTED_REASON_CONTEXT Context);

#endif /* (NTDDI_VERSION >= NTDDI_WIN7) */

/******************************************************************************
 *                          Executive Functions                               *
 ******************************************************************************/

#define ExInterlockedIncrementLong(Addend,Lock) Exfi386InterlockedIncrementLong(Addend)
#define ExInterlockedDecrementLong(Addend,Lock) Exfi386InterlockedDecrementLong(Addend)
#define ExInterlockedExchangeUlong(Target, Value, Lock) Exfi386InterlockedExchangeUlong(Target, Value)

#define ExAcquireSpinLock(Lock, OldIrql) KeAcquireSpinLock((Lock), (OldIrql))
#define ExReleaseSpinLock(Lock, OldIrql) KeReleaseSpinLock((Lock), (OldIrql))
#define ExAcquireSpinLockAtDpcLevel(Lock) KeAcquireSpinLockAtDpcLevel(Lock)
#define ExReleaseSpinLockFromDpcLevel(Lock) KeReleaseSpinLockFromDpcLevel(Lock)

#define ExInitializeSListHead InitializeSListHead

#if defined(_NTHAL_) && defined(_X86_)

NTKERNELAPI
VOID
FASTCALL
ExiAcquireFastMutex(
  IN OUT PFAST_MUTEX FastMutex);

NTKERNELAPI
VOID
FASTCALL
ExiReleaseFastMutex(
  IN OUT PFAST_MUTEX FastMutex);

NTKERNELAPI
BOOLEAN
FASTCALL
ExiTryToAcquireFastMutex(
    IN OUT PFAST_MUTEX FastMutex);

#define ExAcquireFastMutex ExiAcquireFastMutex
#define ExReleaseFastMutex ExiReleaseFastMutex
#define ExTryToAcquireFastMutex ExiTryToAcquireFastMutex

#else

#if (NTDDI_VERSION >= NTDDI_WIN2K)

NTKERNELAPI
VOID
FASTCALL
ExAcquireFastMutex(
  IN OUT PFAST_MUTEX FastMutex);

NTKERNELAPI
VOID
FASTCALL
ExReleaseFastMutex(
  IN OUT PFAST_MUTEX FastMutex);

NTKERNELAPI
BOOLEAN
FASTCALL
ExTryToAcquireFastMutex(
  IN OUT PFAST_MUTEX FastMutex);

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#endif /* defined(_NTHAL_) && defined(_X86_) */

#if defined(_X86_)
#define ExInterlockedAddUlong ExfInterlockedAddUlong
#define ExInterlockedInsertHeadList ExfInterlockedInsertHeadList
#define ExInterlockedInsertTailList ExfInterlockedInsertTailList
#define ExInterlockedRemoveHeadList ExfInterlockedRemoveHeadList
#define ExInterlockedPopEntryList ExfInterlockedPopEntryList
#define ExInterlockedPushEntryList ExfInterlockedPushEntryList
#endif /* defined(_X86_) */

#if defined(_WIN64)

#if defined(_NTDRIVER_) || defined(_NTDDK_) || defined(_NTIFS_) || \
    defined(_NTHAL_) || defined(_NTOSP_)
NTKERNELAPI
USHORT
ExQueryDepthSList(IN PSLIST_HEADER ListHead);
#else
FORCEINLINE
USHORT
ExQueryDepthSList(IN PSLIST_HEADER ListHead)
{
  return (USHORT)(ListHead->Alignment & 0xffff);
}
#endif

NTKERNELAPI
PSLIST_ENTRY
ExpInterlockedFlushSList(
  PSLIST_HEADER ListHead);

NTKERNELAPI
PSLIST_ENTRY
ExpInterlockedPopEntrySList(
  PSLIST_HEADER ListHead);

NTKERNELAPI
PSLIST_ENTRY
ExpInterlockedPushEntrySList(
  PSLIST_HEADER ListHead,
  PSLIST_ENTRY ListEntry);

#define ExInterlockedFlushSList(Head) \
    ExpInterlockedFlushSList(Head)
#define ExInterlockedPopEntrySList(Head, Lock) \
    ExpInterlockedPopEntrySList(Head)
#define ExInterlockedPushEntrySList(Head, Entry, Lock) \
    ExpInterlockedPushEntrySList(Head, Entry)

#else /* !defined(_WIN64) */

#ifdef NONAMELESSUNION
#define ExQueryDepthSList(listhead) (listhead)->s.Depth
#else
#define ExQueryDepthSList(listhead) (listhead)->Depth
#endif

NTKERNELAPI
PSINGLE_LIST_ENTRY
FASTCALL
ExInterlockedFlushSList(
  IN OUT PSLIST_HEADER ListHead);

#endif /* !defined(_WIN64) */

#if defined(_WIN2K_COMPAT_SLIST_USAGE) && defined(_X86_)

NTKERNELAPI
PSINGLE_LIST_ENTRY 
FASTCALL
ExInterlockedPopEntrySList(
  IN PSLIST_HEADER ListHead,
  IN PKSPIN_LOCK Lock);

NTKERNELAPI
PSINGLE_LIST_ENTRY 
FASTCALL
ExInterlockedPushEntrySList(
  IN PSLIST_HEADER ListHead,
  IN PSINGLE_LIST_ENTRY ListEntry,
  IN PKSPIN_LOCK Lock);

NTKERNELAPI
PVOID
NTAPI
ExAllocateFromPagedLookasideList(
  IN OUT PPAGED_LOOKASIDE_LIST Lookaside);

NTKERNELAPI
VOID
NTAPI
ExFreeToPagedLookasideList(
  IN OUT PPAGED_LOOKASIDE_LIST Lookaside,
  IN PVOID Entry);

#else /* !_WIN2K_COMPAT_SLIST_USAGE */

#if !defined(_WIN64)
#define ExInterlockedPopEntrySList(_ListHead, _Lock) \
    InterlockedPopEntrySList(_ListHead)
#define ExInterlockedPushEntrySList(_ListHead, _ListEntry, _Lock) \
    InterlockedPushEntrySList(_ListHead, _ListEntry)
#endif

static __inline
PVOID
ExAllocateFromPagedLookasideList(
  IN OUT PPAGED_LOOKASIDE_LIST Lookaside)
{
  PVOID Entry;

  Lookaside->L.TotalAllocates++;
#ifdef NONAMELESSUNION
  Entry = InterlockedPopEntrySList(&Lookaside->L.u.ListHead);
  if (Entry == NULL) {
    Lookaside->L.u2.AllocateMisses++;
    Entry = (Lookaside->L.u4.Allocate)(Lookaside->L.Type,
                                       Lookaside->L.Size,
                                       Lookaside->L.Tag);
  }
#else /* NONAMELESSUNION */
  Entry = InterlockedPopEntrySList(&Lookaside->L.ListHead);
  if (Entry == NULL) {
    Lookaside->L.AllocateMisses++;
    Entry = (Lookaside->L.Allocate)(Lookaside->L.Type,
                                    Lookaside->L.Size,
                                    Lookaside->L.Tag);
  }
#endif /* NONAMELESSUNION */
  return Entry;
}

static __inline
VOID
ExFreeToPagedLookasideList(
  IN OUT PPAGED_LOOKASIDE_LIST Lookaside,
  IN PVOID Entry)
{
  Lookaside->L.TotalFrees++;
#ifdef NONAMELESSUNION
  if (ExQueryDepthSList(&Lookaside->L.u.ListHead) >= Lookaside->L.Depth) {
    Lookaside->L.u3.FreeMisses++;
    (Lookaside->L.u5.Free)(Entry);
  } else {
    InterlockedPushEntrySList(&Lookaside->L.u.ListHead, (PSLIST_ENTRY)Entry);
  }
#else /* NONAMELESSUNION */
  if (ExQueryDepthSList(&Lookaside->L.ListHead) >= Lookaside->L.Depth) {
    Lookaside->L.FreeMisses++;
    (Lookaside->L.Free)(Entry);
  } else {
    InterlockedPushEntrySList(&Lookaside->L.ListHead, (PSLIST_ENTRY)Entry);
  }
#endif /* NONAMELESSUNION */
}

#endif /* _WIN2K_COMPAT_SLIST_USAGE */


/* ERESOURCE_THREAD
 * ExGetCurrentResourceThread(
 *     VOID);
 */
#define ExGetCurrentResourceThread() ((ULONG_PTR)PsGetCurrentThread())

#define ExReleaseResource(R) (ExReleaseResourceLite(R))

/* VOID
 * ExInitializeWorkItem(
 *     IN PWORK_QUEUE_ITEM Item,
 *     IN PWORKER_THREAD_ROUTINE Routine,
 *     IN PVOID Context)
 */
#define ExInitializeWorkItem(Item, Routine, Context) \
{ \
  (Item)->WorkerRoutine = Routine; \
  (Item)->Parameter = Context; \
  (Item)->List.Flink = NULL; \
}

FORCEINLINE
VOID
ExInitializeFastMutex(
  OUT PFAST_MUTEX FastMutex)
{
  FastMutex->Count = FM_LOCK_BIT;
  FastMutex->Owner = NULL;
  FastMutex->Contention = 0;
  KeInitializeEvent(&FastMutex->Event, SynchronizationEvent, FALSE);
  return;
}


#if (NTDDI_VERSION >= NTDDI_WIN2K)
NTKERNELAPI
VOID
FASTCALL
ExAcquireFastMutexUnsafe(
  IN OUT PFAST_MUTEX FastMutex);

NTKERNELAPI
VOID
FASTCALL
ExReleaseFastMutexUnsafe(
  IN OUT PFAST_MUTEX FastMutex);

NTKERNELAPI
BOOLEAN
NTAPI
ExAcquireResourceExclusiveLite(
  IN OUT PERESOURCE Resource,
  IN BOOLEAN Wait);

NTKERNELAPI
BOOLEAN
NTAPI
ExAcquireResourceSharedLite(
  IN OUT PERESOURCE Resource,
  IN BOOLEAN Wait);

NTKERNELAPI
BOOLEAN
NTAPI
ExAcquireSharedStarveExclusive(
  IN OUT PERESOURCE Resource,
  IN BOOLEAN Wait);

NTKERNELAPI
BOOLEAN
NTAPI
ExAcquireSharedWaitForExclusive(
  IN OUT PERESOURCE Resource,
  IN BOOLEAN Wait);

NTKERNELAPI
PVOID
NTAPI
ExAllocatePool(
  IN POOL_TYPE PoolType,
  IN SIZE_T NumberOfBytes);

NTKERNELAPI
PVOID
NTAPI
ExAllocatePoolWithQuota(
  IN POOL_TYPE PoolType,
  IN SIZE_T NumberOfBytes);

NTKERNELAPI
PVOID
NTAPI
ExAllocatePoolWithQuotaTag(
  IN POOL_TYPE PoolType,
  IN SIZE_T NumberOfBytes,
  IN ULONG Tag);

#ifndef POOL_TAGGING
#define ExAllocatePoolWithQuotaTag(a,b,c) ExAllocatePoolWithQuota(a,b)
#endif

NTKERNELAPI
PVOID
NTAPI
ExAllocatePoolWithTag(
  IN POOL_TYPE PoolType,
  IN SIZE_T NumberOfBytes,
  IN ULONG Tag);

#ifndef POOL_TAGGING
#define ExAllocatePoolWithTag(a,b,c) ExAllocatePool(a,b)
#endif

NTKERNELAPI
PVOID
NTAPI
ExAllocatePoolWithTagPriority(
  IN POOL_TYPE PoolType,
  IN SIZE_T NumberOfBytes,
  IN ULONG Tag,
  IN EX_POOL_PRIORITY Priority);

NTKERNELAPI
VOID
NTAPI
ExConvertExclusiveToSharedLite(
  IN OUT PERESOURCE Resource);

NTKERNELAPI
NTSTATUS
NTAPI
ExCreateCallback(
  OUT PCALLBACK_OBJECT *CallbackObject,
  IN POBJECT_ATTRIBUTES ObjectAttributes,
  IN BOOLEAN Create,
  IN BOOLEAN AllowMultipleCallbacks);

NTKERNELAPI
VOID
NTAPI
ExDeleteNPagedLookasideList(
  IN OUT PNPAGED_LOOKASIDE_LIST Lookaside);

NTKERNELAPI
VOID
NTAPI
ExDeletePagedLookasideList(
  IN PPAGED_LOOKASIDE_LIST Lookaside);

NTKERNELAPI
NTSTATUS
NTAPI
ExDeleteResourceLite(
  IN OUT PERESOURCE Resource);

NTKERNELAPI
VOID
NTAPI
ExFreePool(
  IN PVOID P);

NTKERNELAPI
VOID
NTAPI
ExFreePoolWithTag(
  IN PVOID P,
  IN ULONG Tag);

NTKERNELAPI
ULONG
NTAPI
ExGetExclusiveWaiterCount(
  IN PERESOURCE Resource);

NTKERNELAPI
KPROCESSOR_MODE
NTAPI
ExGetPreviousMode(VOID);

NTKERNELAPI
ULONG
NTAPI
ExGetSharedWaiterCount(
  IN PERESOURCE Resource);

NTKERNELAPI
VOID
NTAPI
ExInitializeNPagedLookasideList(
  IN PNPAGED_LOOKASIDE_LIST Lookaside,
  IN PALLOCATE_FUNCTION Allocate OPTIONAL,
  IN PFREE_FUNCTION Free OPTIONAL,
  IN ULONG Flags,
  IN SIZE_T Size,
  IN ULONG Tag,
  IN USHORT Depth);

NTKERNELAPI
VOID
NTAPI
ExInitializePagedLookasideList(
  IN PPAGED_LOOKASIDE_LIST Lookaside,
  IN PALLOCATE_FUNCTION Allocate OPTIONAL,
  IN PFREE_FUNCTION Free OPTIONAL,
  IN ULONG Flags,
  IN SIZE_T Size,
  IN ULONG Tag,
  IN USHORT Depth);

NTKERNELAPI
NTSTATUS
NTAPI
ExInitializeResourceLite(
  OUT PERESOURCE Resource);

NTKERNELAPI
LARGE_INTEGER
NTAPI
ExInterlockedAddLargeInteger(
  IN PLARGE_INTEGER Addend,
  IN LARGE_INTEGER Increment,
  IN PKSPIN_LOCK Lock);

#if defined(_WIN64)
#define ExInterlockedAddLargeStatistic(Addend, Increment) \
    (VOID)InterlockedAdd64(&(Addend)->QuadPart, Increment)
#else
#define ExInterlockedAddLargeStatistic(Addend, Increment) \
    _InterlockedAddLargeStatistic((PLONGLONG)&(Addend)->QuadPart, Increment)
#endif

NTKERNELAPI
ULONG
FASTCALL
ExInterlockedAddUlong(
  IN PULONG Addend,
  IN ULONG Increment,
  IN OUT PKSPIN_LOCK Lock);

#if defined(_AMD64_) || defined(_IA64_)

#define ExInterlockedCompareExchange64(Destination, Exchange, Comperand, Lock) \
    InterlockedCompareExchange64(Destination, *(Exchange), *(Comperand))

#elif defined(_X86_)

NTKERNELAPI
LONGLONG
FASTCALL
ExfInterlockedCompareExchange64(
  IN OUT LONGLONG volatile *Destination,
  IN PLONGLONG Exchange,
  IN PLONGLONG Comperand);

#define ExInterlockedCompareExchange64(Destination, Exchange, Comperand, Lock) \
    ExfInterlockedCompareExchange64(Destination, Exchange, Comperand)

#else

NTKERNELAPI
LONGLONG
FASTCALL
ExInterlockedCompareExchange64(
  IN OUT LONGLONG volatile *Destination,
  IN PLONGLONG Exchange,
  IN PLONGLONG Comparand,
  IN PKSPIN_LOCK Lock);

#endif /* defined(_AMD64_) || defined(_IA64_) */

NTKERNELAPI
PLIST_ENTRY
FASTCALL
ExInterlockedInsertHeadList(
  IN OUT PLIST_ENTRY ListHead,
  IN OUT PLIST_ENTRY ListEntry,
  IN OUT PKSPIN_LOCK Lock);

NTKERNELAPI
PLIST_ENTRY
FASTCALL
ExInterlockedInsertTailList(
  IN OUT PLIST_ENTRY ListHead,
  IN OUT PLIST_ENTRY ListEntry,
  IN OUT PKSPIN_LOCK Lock);

NTKERNELAPI
PSINGLE_LIST_ENTRY
FASTCALL
ExInterlockedPopEntryList(
  IN OUT PSINGLE_LIST_ENTRY ListHead,
  IN OUT PKSPIN_LOCK Lock);

NTKERNELAPI
PSINGLE_LIST_ENTRY
FASTCALL
ExInterlockedPushEntryList(
  IN OUT PSINGLE_LIST_ENTRY ListHead,
  IN OUT PSINGLE_LIST_ENTRY ListEntry,
  IN OUT PKSPIN_LOCK Lock);

NTKERNELAPI
PLIST_ENTRY
FASTCALL
ExInterlockedRemoveHeadList(
  IN OUT PLIST_ENTRY ListHead,
  IN OUT PKSPIN_LOCK Lock);

NTKERNELAPI
BOOLEAN
NTAPI
ExIsProcessorFeaturePresent(
  IN ULONG ProcessorFeature);

NTKERNELAPI
BOOLEAN
NTAPI
ExIsResourceAcquiredExclusiveLite(
  IN PERESOURCE Resource);

NTKERNELAPI
ULONG
NTAPI
ExIsResourceAcquiredSharedLite(
  IN PERESOURCE Resource);

#define ExIsResourceAcquiredLite ExIsResourceAcquiredSharedLite

NTKERNELAPI
VOID
NTAPI
ExLocalTimeToSystemTime(
  IN PLARGE_INTEGER LocalTime,
  OUT PLARGE_INTEGER SystemTime);

NTKERNELAPI
VOID
NTAPI
ExNotifyCallback(
  IN PCALLBACK_OBJECT CallbackObject,
  IN PVOID Argument1 OPTIONAL,
  IN PVOID Argument2 OPTIONAL);

NTKERNELAPI
VOID
NTAPI
ExQueueWorkItem(
  IN OUT PWORK_QUEUE_ITEM WorkItem,
  IN WORK_QUEUE_TYPE QueueType);

NTKERNELAPI
DECLSPEC_NORETURN
VOID
NTAPI
ExRaiseStatus(
  IN NTSTATUS Status);

NTKERNELAPI
PVOID
NTAPI
ExRegisterCallback(
  IN PCALLBACK_OBJECT CallbackObject,
  IN PCALLBACK_FUNCTION CallbackFunction,
  IN PVOID CallbackContext OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
ExReinitializeResourceLite(
  IN OUT PERESOURCE Resource);

NTKERNELAPI
VOID
NTAPI
ExReleaseResourceForThreadLite(
  IN OUT PERESOURCE Resource,
  IN ERESOURCE_THREAD ResourceThreadId);

NTKERNELAPI
VOID
FASTCALL
ExReleaseResourceLite(
  IN OUT PERESOURCE Resource);

NTKERNELAPI
VOID
NTAPI
ExSetResourceOwnerPointer(
  IN OUT PERESOURCE Resource,
  IN PVOID OwnerPointer);

NTKERNELAPI
ULONG
NTAPI
ExSetTimerResolution(
  IN ULONG DesiredTime,
  IN BOOLEAN SetResolution);

NTKERNELAPI
VOID
NTAPI
ExSystemTimeToLocalTime(
  IN PLARGE_INTEGER SystemTime,
  OUT PLARGE_INTEGER LocalTime);

NTKERNELAPI
VOID
NTAPI
ExUnregisterCallback(
  IN OUT PVOID CbRegistration);

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#if (NTDDI_VERSION >= NTDDI_WINXP)

NTKERNELAPI
BOOLEAN
FASTCALL
ExAcquireRundownProtection(
  IN OUT PEX_RUNDOWN_REF RunRef);

NTKERNELAPI
VOID
FASTCALL
ExInitializeRundownProtection(
  OUT PEX_RUNDOWN_REF RunRef);

NTKERNELAPI
VOID
FASTCALL
ExReInitializeRundownProtection(
  IN OUT PEX_RUNDOWN_REF RunRef);

NTKERNELAPI
VOID
FASTCALL
ExReleaseRundownProtection(
  IN OUT PEX_RUNDOWN_REF RunRef);

NTKERNELAPI
VOID
FASTCALL
ExRundownCompleted(
  OUT PEX_RUNDOWN_REF RunRef);

NTKERNELAPI
BOOLEAN
NTAPI
ExVerifySuite(
  IN SUITE_TYPE SuiteType);

NTKERNELAPI
VOID
FASTCALL
ExWaitForRundownProtectionRelease(
  IN OUT PEX_RUNDOWN_REF RunRef);
#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

#if (NTDDI_VERSION >= NTDDI_WINXPSP2)

NTKERNELAPI
BOOLEAN
FASTCALL
ExAcquireRundownProtectionEx(
  IN OUT PEX_RUNDOWN_REF RunRef,
  IN ULONG Count);

NTKERNELAPI
VOID
FASTCALL
ExReleaseRundownProtectionEx(
  IN OUT PEX_RUNDOWN_REF RunRef,
  IN ULONG Count);

#endif /* (NTDDI_VERSION >= NTDDI_WINXPSP2) */

#if (NTDDI_VERSION >= NTDDI_WS03SP1)

NTKERNELAPI
PEX_RUNDOWN_REF_CACHE_AWARE
NTAPI
ExAllocateCacheAwareRundownProtection(
  IN POOL_TYPE PoolType,
  IN ULONG PoolTag);

NTKERNELAPI
SIZE_T
NTAPI
ExSizeOfRundownProtectionCacheAware(VOID);

NTKERNELAPI
PVOID
NTAPI
ExEnterCriticalRegionAndAcquireResourceShared(
  IN OUT PERESOURCE Resource);

NTKERNELAPI
PVOID
NTAPI
ExEnterCriticalRegionAndAcquireResourceExclusive(
  IN OUT PERESOURCE Resource);

NTKERNELAPI
PVOID
NTAPI
ExEnterCriticalRegionAndAcquireSharedWaitForExclusive(
  IN OUT PERESOURCE Resource);

NTKERNELAPI
VOID
FASTCALL
ExReleaseResourceAndLeaveCriticalRegion(
  IN OUT PERESOURCE Resource);

NTKERNELAPI
VOID
NTAPI
ExInitializeRundownProtectionCacheAware(
  OUT PEX_RUNDOWN_REF_CACHE_AWARE RunRefCacheAware,
  IN SIZE_T RunRefSize);

NTKERNELAPI
VOID
NTAPI
ExFreeCacheAwareRundownProtection(
  IN OUT PEX_RUNDOWN_REF_CACHE_AWARE RunRefCacheAware);

NTKERNELAPI
BOOLEAN
FASTCALL
ExAcquireRundownProtectionCacheAware(
  IN OUT PEX_RUNDOWN_REF_CACHE_AWARE RunRefCacheAware);

NTKERNELAPI
VOID
FASTCALL
ExReleaseRundownProtectionCacheAware(
  IN OUT PEX_RUNDOWN_REF_CACHE_AWARE RunRefCacheAware);

NTKERNELAPI
BOOLEAN
FASTCALL
ExAcquireRundownProtectionCacheAwareEx(
  IN OUT PEX_RUNDOWN_REF_CACHE_AWARE RunRefCacheAware,
  IN ULONG Count);

NTKERNELAPI
VOID
FASTCALL
ExReleaseRundownProtectionCacheAwareEx(
  IN OUT PEX_RUNDOWN_REF_CACHE_AWARE RunRef,
  IN ULONG Count);

NTKERNELAPI
VOID
FASTCALL
ExWaitForRundownProtectionReleaseCacheAware(
  IN OUT PEX_RUNDOWN_REF_CACHE_AWARE RunRef);

NTKERNELAPI
VOID
FASTCALL
ExReInitializeRundownProtectionCacheAware(
  IN OUT PEX_RUNDOWN_REF_CACHE_AWARE RunRefCacheAware);

NTKERNELAPI
VOID
FASTCALL
ExRundownCompletedCacheAware(
  IN OUT PEX_RUNDOWN_REF_CACHE_AWARE RunRefCacheAware);

#endif /* (NTDDI_VERSION >= NTDDI_WS03SP1) */

#if (NTDDI_VERSION >= NTDDI_VISTA)

NTKERNELAPI
NTSTATUS
NTAPI
ExInitializeLookasideListEx(
  OUT PLOOKASIDE_LIST_EX Lookaside,
  IN PALLOCATE_FUNCTION_EX Allocate OPTIONAL,
  IN PFREE_FUNCTION_EX Free OPTIONAL,
  IN POOL_TYPE PoolType,
  IN ULONG Flags,
  IN SIZE_T Size,
  IN ULONG Tag,
  IN USHORT Depth);

NTKERNELAPI
VOID
NTAPI
ExDeleteLookasideListEx(
  IN OUT PLOOKASIDE_LIST_EX Lookaside);

NTKERNELAPI
VOID
NTAPI
ExFlushLookasideListEx(
  IN OUT PLOOKASIDE_LIST_EX Lookaside);

FORCEINLINE
PVOID
ExAllocateFromLookasideListEx(
  IN OUT PLOOKASIDE_LIST_EX Lookaside)
{
  PVOID Entry;

  Lookaside->L.TotalAllocates += 1;
#ifdef NONAMELESSUNION
  Entry = InterlockedPopEntrySList(&Lookaside->L.u.ListHead);
  if (Entry == NULL) {
    Lookaside->L.u2.AllocateMisses += 1;
    Entry = (Lookaside->L.u4.AllocateEx)(Lookaside->L.Type,
                                         Lookaside->L.Size,
                                         Lookaside->L.Tag,
                                         Lookaside);
  }
#else /* NONAMELESSUNION */
  Entry = InterlockedPopEntrySList(&Lookaside->L.ListHead);
  if (Entry == NULL) {
    Lookaside->L.AllocateMisses += 1;
    Entry = (Lookaside->L.AllocateEx)(Lookaside->L.Type,
                                      Lookaside->L.Size,
                                      Lookaside->L.Tag,
                                      Lookaside);
  }
#endif /* NONAMELESSUNION */
  return Entry;
}

FORCEINLINE
VOID
ExFreeToLookasideListEx(
  IN OUT PLOOKASIDE_LIST_EX Lookaside,
  IN PVOID Entry)
{
  Lookaside->L.TotalFrees += 1;
  if (ExQueryDepthSList(&Lookaside->L.ListHead) >= Lookaside->L.Depth) {
    Lookaside->L.FreeMisses += 1;
    (Lookaside->L.FreeEx)(Entry, Lookaside);
  } else {
    InterlockedPushEntrySList(&Lookaside->L.ListHead, (PSLIST_ENTRY)Entry);
  }
  return;
}

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#if (NTDDI_VERSION >= NTDDI_WIN7)

NTKERNELAPI
VOID
NTAPI
ExSetResourceOwnerPointerEx(
  IN OUT PERESOURCE Resource,
  IN PVOID OwnerPointer,
  IN ULONG Flags);

#define FLAG_OWNER_POINTER_IS_THREAD 0x1

#endif /* (NTDDI_VERSION >= NTDDI_WIN7) */

static __inline PVOID
ExAllocateFromNPagedLookasideList(
  IN OUT PNPAGED_LOOKASIDE_LIST Lookaside)
{
  PVOID Entry;

  Lookaside->L.TotalAllocates++;
#ifdef NONAMELESSUNION
#if defined(_WIN2K_COMPAT_SLIST_USAGE) && defined(_X86_)
  Entry = ExInterlockedPopEntrySList(&Lookaside->L.u.ListHead,
                                     &Lookaside->Lock__ObsoleteButDoNotDelete);
#else
  Entry = InterlockedPopEntrySList(&Lookaside->L.u.ListHead);
#endif
  if (Entry == NULL) {
    Lookaside->L.u2.AllocateMisses++;
    Entry = (Lookaside->L.u4.Allocate)(Lookaside->L.Type,
                                       Lookaside->L.Size,
                                       Lookaside->L.Tag);
  }
#else /* NONAMELESSUNION */
#if defined(_WIN2K_COMPAT_SLIST_USAGE) && defined(_X86_)
  Entry = ExInterlockedPopEntrySList(&Lookaside->L.ListHead,
                                     &Lookaside->Lock__ObsoleteButDoNotDelete);
#else
  Entry = InterlockedPopEntrySList(&Lookaside->L.ListHead);
#endif
  if (Entry == NULL) {
    Lookaside->L.AllocateMisses++;
    Entry = (Lookaside->L.Allocate)(Lookaside->L.Type,
                                    Lookaside->L.Size,
                                    Lookaside->L.Tag);
  }
#endif /* NONAMELESSUNION */
  return Entry;
}

static __inline VOID
ExFreeToNPagedLookasideList(
  IN OUT PNPAGED_LOOKASIDE_LIST Lookaside,
  IN PVOID Entry)
{
  Lookaside->L.TotalFrees++;
#ifdef NONAMELESSUNION
  if (ExQueryDepthSList(&Lookaside->L.u.ListHead) >= Lookaside->L.Depth) {
    Lookaside->L.u3.FreeMisses++;
    (Lookaside->L.u5.Free)(Entry);
  } else {
#if defined(_WIN2K_COMPAT_SLIST_USAGE) && defined(_X86_)
      ExInterlockedPushEntrySList(&Lookaside->L.u.ListHead,
                                  (PSLIST_ENTRY)Entry,
                                  &Lookaside->Lock__ObsoleteButDoNotDelete);
#else
      InterlockedPushEntrySList(&Lookaside->L.u.ListHead, (PSLIST_ENTRY)Entry);
#endif
   }
#else /* NONAMELESSUNION */
  if (ExQueryDepthSList(&Lookaside->L.ListHead) >= Lookaside->L.Depth) {
    Lookaside->L.FreeMisses++;
    (Lookaside->L.Free)(Entry);
  } else {
#if defined(_WIN2K_COMPAT_SLIST_USAGE) && defined(_X86_)
      ExInterlockedPushEntrySList(&Lookaside->L.ListHead,
                                  (PSLIST_ENTRY)Entry,
                                  &Lookaside->Lock__ObsoleteButDoNotDelete);
#else
      InterlockedPushEntrySList(&Lookaside->L.ListHead, (PSLIST_ENTRY)Entry);
#endif
   }
#endif /* NONAMELESSUNION */
}

/******************************************************************************
 *                          Object Manager Functions                          *
 ******************************************************************************/

#if (NTDDI_VERSION >= NTDDI_WIN2K)
NTKERNELAPI
LONG_PTR
FASTCALL
ObfDereferenceObject(
  IN PVOID Object);
#define ObDereferenceObject ObfDereferenceObject

NTKERNELAPI
NTSTATUS
NTAPI
ObGetObjectSecurity(
  IN PVOID Object,
  OUT PSECURITY_DESCRIPTOR *SecurityDescriptor,
  OUT PBOOLEAN MemoryAllocated);

NTKERNELAPI
LONG_PTR
FASTCALL
ObfReferenceObject(
  IN PVOID Object);
#define ObReferenceObject ObfReferenceObject

NTKERNELAPI
NTSTATUS
NTAPI
ObReferenceObjectByHandle(
  IN HANDLE Handle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_TYPE ObjectType OPTIONAL,
  IN KPROCESSOR_MODE AccessMode,
  OUT PVOID *Object,
  OUT POBJECT_HANDLE_INFORMATION HandleInformation OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
ObReferenceObjectByPointer(
  IN PVOID Object,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_TYPE ObjectType OPTIONAL,
  IN KPROCESSOR_MODE AccessMode);

NTKERNELAPI
VOID
NTAPI
ObReleaseObjectSecurity(
  IN PSECURITY_DESCRIPTOR SecurityDescriptor,
  IN BOOLEAN MemoryAllocated);
#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#if (NTDDI_VERSION >= NTDDI_VISTA)
NTKERNELAPI
VOID
NTAPI
ObDereferenceObjectDeferDelete(
  IN PVOID Object);
#endif

#if (NTDDI_VERSION >= NTDDI_VISTASP1)
NTKERNELAPI
NTSTATUS
NTAPI
ObRegisterCallbacks(
  IN POB_CALLBACK_REGISTRATION CallbackRegistration,
  OUT PVOID *RegistrationHandle);

NTKERNELAPI
VOID
NTAPI
ObUnRegisterCallbacks(
  IN PVOID RegistrationHandle);

NTKERNELAPI
USHORT
NTAPI
ObGetFilterVersion(VOID);

#endif /* (NTDDI_VERSION >= NTDDI_VISTASP1) */

#if (NTDDI_VERSION >= NTDDI_WIN7)
NTKERNELAPI
NTSTATUS
NTAPI
ObReferenceObjectByHandleWithTag(
  IN HANDLE Handle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_TYPE ObjectType OPTIONAL,
  IN KPROCESSOR_MODE AccessMode,
  IN ULONG Tag,
  OUT PVOID *Object,
  OUT POBJECT_HANDLE_INFORMATION HandleInformation OPTIONAL);

NTKERNELAPI
LONG_PTR
FASTCALL
ObfReferenceObjectWithTag(
  IN PVOID Object,
  IN ULONG Tag);

NTKERNELAPI
NTSTATUS
NTAPI
ObReferenceObjectByPointerWithTag(
  IN PVOID Object,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_TYPE ObjectType OPTIONAL,
  IN KPROCESSOR_MODE AccessMode,
  IN ULONG Tag);

NTKERNELAPI
LONG_PTR
FASTCALL
ObfDereferenceObjectWithTag(
  IN PVOID Object,
  IN ULONG Tag);

NTKERNELAPI
VOID
NTAPI
ObDereferenceObjectDeferDeleteWithTag(
  IN PVOID Object,
  IN ULONG Tag);

#define ObDereferenceObject ObfDereferenceObject
#define ObReferenceObject ObfReferenceObject
#define ObDereferenceObjectWithTag ObfDereferenceObjectWithTag
#define ObReferenceObjectWithTag ObfReferenceObjectWithTag
#endif /* (NTDDI_VERSION >= NTDDI_WIN7) */

/******************************************************************************
 *                          Process Manager Functions                         *
 ******************************************************************************/

NTKERNELAPI
NTSTATUS
NTAPI
PsWrapApcWow64Thread(
  IN OUT PVOID *ApcContext,
  IN OUT PVOID *ApcRoutine);

/*
 * PEPROCESS
 * PsGetCurrentProcess(VOID)
 */
#define PsGetCurrentProcess IoGetCurrentProcess

#if !defined(_PSGETCURRENTTHREAD_)
#define _PSGETCURRENTTHREAD_
FORCEINLINE
PETHREAD
NTAPI
PsGetCurrentThread(VOID)
{
  return (PETHREAD)KeGetCurrentThread();
}
#endif /* !_PSGETCURRENTTHREAD_ */


#if (NTDDI_VERSION >= NTDDI_WIN2K)

NTKERNELAPI
NTSTATUS
NTAPI
PsCreateSystemThread(
  OUT PHANDLE ThreadHandle,
  IN ULONG DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
  IN HANDLE ProcessHandle OPTIONAL,
  OUT PCLIENT_ID ClientId OPTIONAL,
  IN PKSTART_ROUTINE StartRoutine,
  IN PVOID StartContext OPTIONAL);

NTKERNELAPI
NTSTATUS
NTAPI
PsTerminateSystemThread(
  IN NTSTATUS ExitStatus);

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */


/******************************************************************************
 *                          WMI Library Support Functions                     *
 ******************************************************************************/

#ifdef RUN_WPP
#if (NTDDI_VERSION >= NTDDI_WINXP)
NTKERNELAPI
NTSTATUS
__cdecl
WmiTraceMessage(
  IN TRACEHANDLE LoggerHandle,
  IN ULONG MessageFlags,
  IN LPGUID MessageGuid,
  IN USHORT MessageNumber,
  IN ...);
#endif
#endif /* RUN_WPP */

#if (NTDDI_VERSION >= NTDDI_WINXP)

NTKERNELAPI
NTSTATUS
NTAPI
WmiQueryTraceInformation(
  IN TRACE_INFORMATION_CLASS TraceInformationClass,
  OUT PVOID TraceInformation,
  IN ULONG TraceInformationLength,
  OUT PULONG RequiredLength OPTIONAL,
  IN PVOID Buffer OPTIONAL);

#if 0
/* FIXME: Get va_list from where? */
NTKERNELAPI
NTSTATUS
NTAPI
WmiTraceMessageVa(
  IN TRACEHANDLE LoggerHandle,
  IN ULONG MessageFlags,
  IN LPGUID MessageGuid,
  IN USHORT MessageNumber,
  IN va_list MessageArgList);
#endif

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

#ifndef TRACE_INFORMATION_CLASS_DEFINE

#if (NTDDI_VERSION >= NTDDI_WINXP)
NTKERNELAPI
NTSTATUS
NTAPI
WmiQueryTraceInformation(
  IN TRACE_INFORMATION_CLASS TraceInformationClass,
  OUT PVOID TraceInformation,
  IN ULONG TraceInformationLength,
  OUT PULONG RequiredLength OPTIONAL,
  IN PVOID Buffer OPTIONAL);
#endif

#define TRACE_INFORMATION_CLASS_DEFINE

#endif /* TRACE_INFOPRMATION_CLASS_DEFINE */

#if (NTDDI_VERSION >= NTDDI_VISTA)

NTSTATUS
NTKERNELAPI
NTAPI
EtwRegister(
  IN LPCGUID ProviderId,
  IN PETWENABLECALLBACK EnableCallback OPTIONAL,
  IN PVOID CallbackContext OPTIONAL,
  OUT PREGHANDLE RegHandle);

NTSTATUS
NTKERNELAPI
NTAPI
EtwUnregister(
  IN REGHANDLE RegHandle);

BOOLEAN
NTKERNELAPI
NTAPI
EtwEventEnabled(
  IN REGHANDLE RegHandle,
  IN PCEVENT_DESCRIPTOR EventDescriptor);

BOOLEAN
NTKERNELAPI
NTAPI
EtwProviderEnabled(
  IN REGHANDLE RegHandle,
  IN UCHAR Level,
  IN ULONGLONG Keyword);

NTSTATUS
NTKERNELAPI
NTAPI
EtwActivityIdControl(
  IN ULONG ControlCode,
  IN OUT LPGUID ActivityId);

NTSTATUS
NTKERNELAPI
NTAPI
EtwWrite(
  IN REGHANDLE RegHandle,
  IN PCEVENT_DESCRIPTOR EventDescriptor,
  IN LPCGUID ActivityId OPTIONAL,
  IN ULONG UserDataCount,
  IN PEVENT_DATA_DESCRIPTOR  UserData OPTIONAL);

NTSTATUS
NTKERNELAPI
NTAPI
EtwWriteTransfer(
  IN REGHANDLE RegHandle,
  IN PCEVENT_DESCRIPTOR EventDescriptor,
  IN LPCGUID ActivityId OPTIONAL,
  IN LPCGUID RelatedActivityId OPTIONAL,
  IN ULONG UserDataCount,
  IN PEVENT_DATA_DESCRIPTOR UserData OPTIONAL);

NTSTATUS
NTKERNELAPI
NTAPI
EtwWriteString(
  IN REGHANDLE RegHandle,
  IN UCHAR Level,
  IN ULONGLONG Keyword,
  IN LPCGUID ActivityId OPTIONAL,
  IN PCWSTR String);

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#if (NTDDI_VERSION >= NTDDI_WIN7)
NTSTATUS
NTKERNELAPI
NTAPI
EtwWriteEx(
  IN REGHANDLE RegHandle,
  IN PCEVENT_DESCRIPTOR EventDescriptor,
  IN ULONG64 Filter,
  IN ULONG Flags,
  IN LPCGUID ActivityId OPTIONAL,
  IN LPCGUID RelatedActivityId OPTIONAL,
  IN ULONG UserDataCount,
  IN PEVENT_DATA_DESCRIPTOR UserData OPTIONAL);
#endif



/******************************************************************************
 *                          Kernel Debugger Functions                         *
 ******************************************************************************/

#ifndef _DBGNT_

ULONG
__cdecl
DbgPrint(
  IN PCSTR Format,
  IN ...);

#if (NTDDI_VERSION >= NTDDI_WIN2K)
NTSYSAPI
ULONG
__cdecl
DbgPrintReturnControlC(
  IN PCCH Format,
  IN ...);
#endif

#if (NTDDI_VERSION >= NTDDI_WINXP)

NTSYSAPI
ULONG
__cdecl
DbgPrintEx(
  IN ULONG ComponentId,
  IN ULONG Level,
  IN PCSTR Format,
  IN ...);

#ifdef _VA_LIST_DEFINED

NTSYSAPI
ULONG
NTAPI
vDbgPrintEx(
  IN ULONG ComponentId,
  IN ULONG Level,
  IN PCCH Format,
  IN va_list ap);

NTSYSAPI
ULONG
NTAPI
vDbgPrintExWithPrefix(
  IN PCCH Prefix,
  IN ULONG ComponentId,
  IN ULONG Level,
  IN PCCH Format,
  IN va_list ap);

#endif /* _VA_LIST_DEFINED */

NTSYSAPI
NTSTATUS
NTAPI
DbgQueryDebugFilterState(
  IN ULONG ComponentId,
  IN ULONG Level);

NTSYSAPI
NTSTATUS
NTAPI
DbgSetDebugFilterState(
  IN ULONG ComponentId,
  IN ULONG Level,
  IN BOOLEAN State);

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

#if (NTDDI_VERSION >= NTDDI_VISTA)

typedef VOID
(*PDEBUG_PRINT_CALLBACK)(
  IN PSTRING Output,
  IN ULONG ComponentId,
  IN ULONG Level);

NTSYSAPI
NTSTATUS
NTAPI
DbgSetDebugPrintCallback(
  IN PDEBUG_PRINT_CALLBACK DebugPrintCallback,
  IN BOOLEAN Enable);

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#endif /* _DBGNT_ */

#if DBG

#define KdPrint(_x_) DbgPrint _x_
#define KdPrintEx(_x_) DbgPrintEx _x_
#define vKdPrintEx(_x_) vDbgPrintEx _x_
#define vKdPrintExWithPrefix(_x_) vDbgPrintExWithPrefix _x_
#define KdBreakPoint() DbgBreakPoint()
#define KdBreakPointWithStatus(s) DbgBreakPointWithStatus(s)

#else /* !DBG */

#define KdPrint(_x_)
#define KdPrintEx(_x_)
#define vKdPrintEx(_x_)
#define vKdPrintExWithPrefix(_x_)
#define KdBreakPoint()
#define KdBreakPointWithStatus(s)

#endif /* !DBG */

#if defined(__GNUC__)

extern NTKERNELAPI BOOLEAN KdDebuggerNotPresent;
extern NTKERNELAPI BOOLEAN KdDebuggerEnabled;
#define KD_DEBUGGER_ENABLED KdDebuggerEnabled
#define KD_DEBUGGER_NOT_PRESENT KdDebuggerNotPresent

#elif defined(_NTDDK_) || defined(_NTIFS_) || defined(_NTHAL_) || defined(_WDMDDK_) || defined(_NTOSP_)

extern NTKERNELAPI PBOOLEAN KdDebuggerNotPresent;
extern NTKERNELAPI PBOOLEAN KdDebuggerEnabled;
#define KD_DEBUGGER_ENABLED *KdDebuggerEnabled
#define KD_DEBUGGER_NOT_PRESENT *KdDebuggerNotPresent

#else

extern BOOLEAN KdDebuggerNotPresent;
extern BOOLEAN KdDebuggerEnabled;
#define KD_DEBUGGER_ENABLED KdDebuggerEnabled
#define KD_DEBUGGER_NOT_PRESENT KdDebuggerNotPresent

#endif

#if (NTDDI_VERSION >= NTDDI_WIN2K)

NTKERNELAPI
NTSTATUS
NTAPI
KdDisableDebugger(VOID);

NTKERNELAPI
NTSTATUS
NTAPI
KdEnableDebugger(VOID);

#if (_MSC_FULL_VER >= 150030729) && !defined(IMPORT_NATIVE_DBG_BREAK)
#define DbgBreakPoint __debugbreak
#else
VOID
NTAPI
DbgBreakPoint(VOID);
#endif

NTSYSAPI
VOID
NTAPI
DbgBreakPointWithStatus(
  IN ULONG Status);

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#if (NTDDI_VERSION >= NTDDI_WS03)
NTKERNELAPI
BOOLEAN
NTAPI
KdRefreshDebuggerNotPresent(VOID);
#endif

#if (NTDDI_VERSION >= NTDDI_WS03SP1)
NTKERNELAPI
NTSTATUS
NTAPI
KdChangeOption(
  IN KD_OPTION Option,
  IN ULONG InBufferBytes OPTIONAL,
  IN PVOID InBuffer,
  IN ULONG OutBufferBytes OPTIONAL,
  OUT PVOID OutBuffer,
  OUT PULONG OutBufferNeeded OPTIONAL);
#endif
/* Hardware Abstraction Layer Functions */

#if (NTDDI_VERSION >= NTDDI_WIN2K)

#if defined(USE_DMA_MACROS) && !defined(_NTHAL_) && (defined(_NTDDK_) || defined(_NTDRIVER_)) || defined(_WDM_INCLUDED_)

FORCEINLINE
PVOID
NTAPI
HalAllocateCommonBuffer(
  IN PDMA_ADAPTER DmaAdapter,
  IN ULONG Length,
  OUT PPHYSICAL_ADDRESS LogicalAddress,
  IN BOOLEAN CacheEnabled)
{
  PALLOCATE_COMMON_BUFFER allocateCommonBuffer;
  PVOID commonBuffer;

  allocateCommonBuffer = *(DmaAdapter)->DmaOperations->AllocateCommonBuffer;
  ASSERT( allocateCommonBuffer != NULL );
  commonBuffer = allocateCommonBuffer( DmaAdapter, Length, LogicalAddress, CacheEnabled );
  return commonBuffer;
}

FORCEINLINE
VOID
NTAPI
HalFreeCommonBuffer(
  IN PDMA_ADAPTER DmaAdapter,
  IN ULONG Length,
  IN PHYSICAL_ADDRESS LogicalAddress,
  IN PVOID VirtualAddress,
  IN BOOLEAN CacheEnabled)
{
  PFREE_COMMON_BUFFER freeCommonBuffer;

  freeCommonBuffer = *(DmaAdapter)->DmaOperations->FreeCommonBuffer;
  ASSERT( freeCommonBuffer != NULL );
  freeCommonBuffer( DmaAdapter, Length, LogicalAddress, VirtualAddress, CacheEnabled );
}

FORCEINLINE
ULONG
NTAPI
HalReadDmaCounter(
  IN PDMA_ADAPTER DmaAdapter)
{
  PREAD_DMA_COUNTER readDmaCounter;
  ULONG counter;

  readDmaCounter = *(DmaAdapter)->DmaOperations->ReadDmaCounter;
  ASSERT( readDmaCounter != NULL );
  counter = readDmaCounter( DmaAdapter );
  return counter;
}

FORCEINLINE
ULONG
HalGetDmaAlignment(
  IN PDMA_ADAPTER DmaAdapter)
{
  PGET_DMA_ALIGNMENT getDmaAlignment;
  ULONG alignment;

  getDmaAlignment = *(DmaAdapter)->DmaOperations->GetDmaAlignment;
  ASSERT( getDmaAlignment != NULL );
  alignment = getDmaAlignment( DmaAdapter );
  return alignment;
}

#endif /* USE_DMA_MACROS ... */

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */

#ifndef _NTTMAPI_
#define _NTTMAPI_

#include <ktmtypes.h>

#define TRANSACTIONMANAGER_QUERY_INFORMATION     (0x0001)
#define TRANSACTIONMANAGER_SET_INFORMATION       (0x0002)
#define TRANSACTIONMANAGER_RECOVER               (0x0004)
#define TRANSACTIONMANAGER_RENAME                (0x0008)
#define TRANSACTIONMANAGER_CREATE_RM             (0x0010)
#define TRANSACTIONMANAGER_BIND_TRANSACTION      (0x0020)

#define TRANSACTIONMANAGER_GENERIC_READ            (STANDARD_RIGHTS_READ            |\
                                                    TRANSACTIONMANAGER_QUERY_INFORMATION)

#define TRANSACTIONMANAGER_GENERIC_WRITE           (STANDARD_RIGHTS_WRITE           |\
                                                    TRANSACTIONMANAGER_SET_INFORMATION     |\
                                                    TRANSACTIONMANAGER_RECOVER             |\
                                                    TRANSACTIONMANAGER_RENAME              |\
                                                    TRANSACTIONMANAGER_CREATE_RM)

#define TRANSACTIONMANAGER_GENERIC_EXECUTE         (STANDARD_RIGHTS_EXECUTE)

#define TRANSACTIONMANAGER_ALL_ACCESS              (STANDARD_RIGHTS_REQUIRED        |\
                                                    TRANSACTIONMANAGER_GENERIC_READ        |\
                                                    TRANSACTIONMANAGER_GENERIC_WRITE       |\
                                                    TRANSACTIONMANAGER_GENERIC_EXECUTE     |\
                                                    TRANSACTIONMANAGER_BIND_TRANSACTION)

#define TRANSACTION_QUERY_INFORMATION     (0x0001)
#define TRANSACTION_SET_INFORMATION       (0x0002)
#define TRANSACTION_ENLIST                (0x0004)
#define TRANSACTION_COMMIT                (0x0008)
#define TRANSACTION_ROLLBACK              (0x0010)
#define TRANSACTION_PROPAGATE             (0x0020)
#define TRANSACTION_RIGHT_RESERVED1       (0x0040)

#define TRANSACTION_GENERIC_READ            (STANDARD_RIGHTS_READ            |\
                                             TRANSACTION_QUERY_INFORMATION   |\
                                             SYNCHRONIZE)

#define TRANSACTION_GENERIC_WRITE           (STANDARD_RIGHTS_WRITE           |\
                                             TRANSACTION_SET_INFORMATION     |\
                                             TRANSACTION_COMMIT              |\
                                             TRANSACTION_ENLIST              |\
                                             TRANSACTION_ROLLBACK            |\
                                             TRANSACTION_PROPAGATE           |\
                                             SYNCHRONIZE)

#define TRANSACTION_GENERIC_EXECUTE         (STANDARD_RIGHTS_EXECUTE         |\
                                             TRANSACTION_COMMIT              |\
                                             TRANSACTION_ROLLBACK            |\
                                             SYNCHRONIZE)

#define TRANSACTION_ALL_ACCESS              (STANDARD_RIGHTS_REQUIRED        |\
                                             TRANSACTION_GENERIC_READ        |\
                                             TRANSACTION_GENERIC_WRITE       |\
                                             TRANSACTION_GENERIC_EXECUTE)

#define TRANSACTION_RESOURCE_MANAGER_RIGHTS (TRANSACTION_GENERIC_READ        |\
                                             STANDARD_RIGHTS_WRITE           |\
                                             TRANSACTION_SET_INFORMATION     |\
                                             TRANSACTION_ENLIST              |\
                                             TRANSACTION_ROLLBACK            |\
                                             TRANSACTION_PROPAGATE           |\
                                             SYNCHRONIZE)

#define RESOURCEMANAGER_QUERY_INFORMATION        (0x0001)
#define RESOURCEMANAGER_SET_INFORMATION          (0x0002)
#define RESOURCEMANAGER_RECOVER                  (0x0004)
#define RESOURCEMANAGER_ENLIST                   (0x0008)
#define RESOURCEMANAGER_GET_NOTIFICATION         (0x0010)
#define RESOURCEMANAGER_REGISTER_PROTOCOL        (0x0020)
#define RESOURCEMANAGER_COMPLETE_PROPAGATION     (0x0040)

#define RESOURCEMANAGER_GENERIC_READ        (STANDARD_RIGHTS_READ                 |\
                                             RESOURCEMANAGER_QUERY_INFORMATION    |\
                                             SYNCHRONIZE)

#define RESOURCEMANAGER_GENERIC_WRITE       (STANDARD_RIGHTS_WRITE                |\
                                             RESOURCEMANAGER_SET_INFORMATION      |\
                                             RESOURCEMANAGER_RECOVER              |\
                                             RESOURCEMANAGER_ENLIST               |\
                                             RESOURCEMANAGER_GET_NOTIFICATION     |\
                                             RESOURCEMANAGER_REGISTER_PROTOCOL    |\
                                             RESOURCEMANAGER_COMPLETE_PROPAGATION |\
                                             SYNCHRONIZE)

#define RESOURCEMANAGER_GENERIC_EXECUTE     (STANDARD_RIGHTS_EXECUTE              |\
                                             RESOURCEMANAGER_RECOVER              |\
                                             RESOURCEMANAGER_ENLIST               |\
                                             RESOURCEMANAGER_GET_NOTIFICATION     |\
                                             RESOURCEMANAGER_COMPLETE_PROPAGATION |\
                                             SYNCHRONIZE)

#define RESOURCEMANAGER_ALL_ACCESS          (STANDARD_RIGHTS_REQUIRED             |\
                                             RESOURCEMANAGER_GENERIC_READ         |\
                                             RESOURCEMANAGER_GENERIC_WRITE        |\
                                             RESOURCEMANAGER_GENERIC_EXECUTE)

#define ENLISTMENT_QUERY_INFORMATION             (0x0001)
#define ENLISTMENT_SET_INFORMATION               (0x0002)
#define ENLISTMENT_RECOVER                       (0x0004)
#define ENLISTMENT_SUBORDINATE_RIGHTS            (0x0008)
#define ENLISTMENT_SUPERIOR_RIGHTS               (0x0010)

#define ENLISTMENT_GENERIC_READ        (STANDARD_RIGHTS_READ           |\
                                        ENLISTMENT_QUERY_INFORMATION)

#define ENLISTMENT_GENERIC_WRITE       (STANDARD_RIGHTS_WRITE          |\
                                        ENLISTMENT_SET_INFORMATION     |\
                                        ENLISTMENT_RECOVER             |\
                                        ENLISTMENT_SUBORDINATE_RIGHTS  |\
                                        ENLISTMENT_SUPERIOR_RIGHTS)

#define ENLISTMENT_GENERIC_EXECUTE     (STANDARD_RIGHTS_EXECUTE        |\
                                        ENLISTMENT_RECOVER             |\
                                        ENLISTMENT_SUBORDINATE_RIGHTS  |\
                                        ENLISTMENT_SUPERIOR_RIGHTS)

#define ENLISTMENT_ALL_ACCESS          (STANDARD_RIGHTS_REQUIRED       |\
                                        ENLISTMENT_GENERIC_READ        |\
                                        ENLISTMENT_GENERIC_WRITE       |\
                                        ENLISTMENT_GENERIC_EXECUTE)

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
  ULONG State;
  ULONG Outcome;
} TRANSACTION_BASIC_INFORMATION, *PTRANSACTION_BASIC_INFORMATION;

typedef struct _TRANSACTIONMANAGER_BASIC_INFORMATION {
  GUID TmIdentity;
  LARGE_INTEGER VirtualClock;
} TRANSACTIONMANAGER_BASIC_INFORMATION, *PTRANSACTIONMANAGER_BASIC_INFORMATION;

typedef struct _TRANSACTIONMANAGER_LOG_INFORMATION {
  GUID LogIdentity;
} TRANSACTIONMANAGER_LOG_INFORMATION, *PTRANSACTIONMANAGER_LOG_INFORMATION;

typedef struct _TRANSACTIONMANAGER_LOGPATH_INFORMATION {
  ULONG LogPathLength;
  WCHAR LogPath[1];
} TRANSACTIONMANAGER_LOGPATH_INFORMATION, *PTRANSACTIONMANAGER_LOGPATH_INFORMATION;

typedef struct _TRANSACTIONMANAGER_RECOVERY_INFORMATION {
  ULONGLONG LastRecoveredLsn;
} TRANSACTIONMANAGER_RECOVERY_INFORMATION, *PTRANSACTIONMANAGER_RECOVERY_INFORMATION;

typedef struct _TRANSACTION_PROPERTIES_INFORMATION {
  ULONG IsolationLevel;
  ULONG IsolationFlags;
  LARGE_INTEGER Timeout;
  ULONG Outcome;
  ULONG DescriptionLength;
  WCHAR Description[1];
} TRANSACTION_PROPERTIES_INFORMATION, *PTRANSACTION_PROPERTIES_INFORMATION;

typedef struct _TRANSACTION_BIND_INFORMATION {
  HANDLE TmHandle;
} TRANSACTION_BIND_INFORMATION, *PTRANSACTION_BIND_INFORMATION;

typedef struct _TRANSACTION_ENLISTMENT_PAIR {
  GUID EnlistmentId;
  GUID ResourceManagerId;
} TRANSACTION_ENLISTMENT_PAIR, *PTRANSACTION_ENLISTMENT_PAIR;

typedef struct _TRANSACTION_ENLISTMENTS_INFORMATION {
  ULONG NumberOfEnlistments;
  TRANSACTION_ENLISTMENT_PAIR EnlistmentPair[1];
} TRANSACTION_ENLISTMENTS_INFORMATION, *PTRANSACTION_ENLISTMENTS_INFORMATION;

typedef struct _TRANSACTION_SUPERIOR_ENLISTMENT_INFORMATION {
  TRANSACTION_ENLISTMENT_PAIR SuperiorEnlistmentPair;
} TRANSACTION_SUPERIOR_ENLISTMENT_INFORMATION, *PTRANSACTION_SUPERIOR_ENLISTMENT_INFORMATION;

typedef struct _RESOURCEMANAGER_BASIC_INFORMATION {
  GUID ResourceManagerId;
  ULONG DescriptionLength;
  WCHAR Description[1];
} RESOURCEMANAGER_BASIC_INFORMATION, *PRESOURCEMANAGER_BASIC_INFORMATION;

typedef struct _RESOURCEMANAGER_COMPLETION_INFORMATION {
  HANDLE IoCompletionPortHandle;
  ULONG_PTR CompletionKey;
} RESOURCEMANAGER_COMPLETION_INFORMATION, *PRESOURCEMANAGER_COMPLETION_INFORMATION;

typedef enum _KTMOBJECT_TYPE {
  KTMOBJECT_TRANSACTION,
  KTMOBJECT_TRANSACTION_MANAGER,
  KTMOBJECT_RESOURCE_MANAGER,
  KTMOBJECT_ENLISTMENT,
  KTMOBJECT_INVALID
} KTMOBJECT_TYPE, *PKTMOBJECT_TYPE;

typedef struct _KTMOBJECT_CURSOR {
  GUID LastQuery;
  ULONG ObjectIdCount;
  GUID ObjectIds[1];
} KTMOBJECT_CURSOR, *PKTMOBJECT_CURSOR;

typedef enum _TRANSACTION_INFORMATION_CLASS {
  TransactionBasicInformation,
  TransactionPropertiesInformation,
  TransactionEnlistmentInformation,
  TransactionSuperiorEnlistmentInformation
} TRANSACTION_INFORMATION_CLASS;

typedef enum _TRANSACTIONMANAGER_INFORMATION_CLASS {
  TransactionManagerBasicInformation,
  TransactionManagerLogInformation,
  TransactionManagerLogPathInformation,
  TransactionManagerRecoveryInformation = 4
} TRANSACTIONMANAGER_INFORMATION_CLASS;

typedef enum _RESOURCEMANAGER_INFORMATION_CLASS {
  ResourceManagerBasicInformation,
  ResourceManagerCompletionInformation,
} RESOURCEMANAGER_INFORMATION_CLASS;

typedef struct _ENLISTMENT_BASIC_INFORMATION {
  GUID EnlistmentId;
  GUID TransactionId;
  GUID ResourceManagerId;
} ENLISTMENT_BASIC_INFORMATION, *PENLISTMENT_BASIC_INFORMATION;

typedef struct _ENLISTMENT_CRM_INFORMATION {
  GUID CrmTransactionManagerId;
  GUID CrmResourceManagerId;
  GUID CrmEnlistmentId;
} ENLISTMENT_CRM_INFORMATION, *PENLISTMENT_CRM_INFORMATION;

typedef enum _ENLISTMENT_INFORMATION_CLASS {
  EnlistmentBasicInformation,
  EnlistmentRecoveryInformation,
  EnlistmentCrmInformation
} ENLISTMENT_INFORMATION_CLASS;

typedef struct _TRANSACTION_LIST_ENTRY {
/* UOW is typedef'ed as GUID just above.  Changed type of UOW
 * member from UOW to GUID for C++ compat.  Using ::UOW for C++
 * works too but we were reported some problems in corner cases
 */
  GUID UOW;
} TRANSACTION_LIST_ENTRY, *PTRANSACTION_LIST_ENTRY;

typedef struct _TRANSACTION_LIST_INFORMATION {
  ULONG NumberOfTransactions;
  TRANSACTION_LIST_ENTRY TransactionInformation[1];
} TRANSACTION_LIST_INFORMATION, *PTRANSACTION_LIST_INFORMATION;

typedef NTSTATUS
(NTAPI *PFN_NT_CREATE_TRANSACTION)(
  OUT PHANDLE TransactionHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
  IN LPGUID Uow OPTIONAL,
  IN HANDLE TmHandle OPTIONAL,
  IN ULONG CreateOptions OPTIONAL,
  IN ULONG IsolationLevel OPTIONAL,
  IN ULONG IsolationFlags OPTIONAL,
  IN PLARGE_INTEGER Timeout OPTIONAL,
  IN PUNICODE_STRING Description OPTIONAL);

typedef NTSTATUS
(NTAPI *PFN_NT_OPEN_TRANSACTION)(
  OUT PHANDLE TransactionHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes,
  IN LPGUID Uow OPTIONAL,
  IN HANDLE TmHandle OPTIONAL);

typedef NTSTATUS
(NTAPI *PFN_NT_QUERY_INFORMATION_TRANSACTION)(
  IN HANDLE TransactionHandle,
  IN TRANSACTION_INFORMATION_CLASS TransactionInformationClass,
  OUT PVOID TransactionInformation,
  IN ULONG TransactionInformationLength,
  OUT PULONG ReturnLength OPTIONAL);

typedef NTSTATUS
(NTAPI *PFN_NT_SET_INFORMATION_TRANSACTION)(
  IN HANDLE TransactionHandle,
  IN TRANSACTION_INFORMATION_CLASS TransactionInformationClass,
  IN PVOID TransactionInformation,
  IN ULONG TransactionInformationLength);

typedef NTSTATUS
(NTAPI *PFN_NT_COMMIT_TRANSACTION)(
  IN HANDLE TransactionHandle,
  IN BOOLEAN Wait);

typedef NTSTATUS
(NTAPI *PFN_NT_ROLLBACK_TRANSACTION)(
  IN HANDLE TransactionHandle,
  IN BOOLEAN Wait);

#if (NTDDI_VERSION >= NTDDI_VISTA)

NTSYSCALLAPI
NTSTATUS
NTAPI
NtCreateTransactionManager(
  OUT PHANDLE TmHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
  IN PUNICODE_STRING LogFileName OPTIONAL,
  IN ULONG CreateOptions OPTIONAL,
  IN ULONG CommitStrength OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtOpenTransactionManager(
  OUT PHANDLE TmHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
  IN PUNICODE_STRING LogFileName OPTIONAL,
  IN LPGUID TmIdentity OPTIONAL,
  IN ULONG OpenOptions OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtRenameTransactionManager(
  IN PUNICODE_STRING LogFileName,
  IN LPGUID ExistingTransactionManagerGuid);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtRollforwardTransactionManager(
  IN HANDLE TransactionManagerHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtRecoverTransactionManager(
  IN HANDLE TransactionManagerHandle);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtQueryInformationTransactionManager(
  IN HANDLE TransactionManagerHandle,
  IN TRANSACTIONMANAGER_INFORMATION_CLASS TransactionManagerInformationClass,
  OUT PVOID TransactionManagerInformation,
  IN ULONG TransactionManagerInformationLength,
  OUT PULONG ReturnLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtSetInformationTransactionManager(
  IN HANDLE TmHandle OPTIONAL,
  IN TRANSACTIONMANAGER_INFORMATION_CLASS TransactionManagerInformationClass,
  IN PVOID TransactionManagerInformation,
  IN ULONG TransactionManagerInformationLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtEnumerateTransactionObject(
  IN HANDLE RootObjectHandle OPTIONAL,
  IN KTMOBJECT_TYPE QueryType,
  IN OUT PKTMOBJECT_CURSOR ObjectCursor,
  IN ULONG ObjectCursorLength,
  OUT PULONG ReturnLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtCreateTransaction(
  OUT PHANDLE TransactionHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
  IN LPGUID Uow OPTIONAL,
  IN HANDLE TmHandle OPTIONAL,
  IN ULONG CreateOptions OPTIONAL,
  IN ULONG IsolationLevel OPTIONAL,
  IN ULONG IsolationFlags OPTIONAL,
  IN PLARGE_INTEGER Timeout OPTIONAL,
  IN PUNICODE_STRING Description OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtOpenTransaction(
  OUT PHANDLE TransactionHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes,
  IN LPGUID Uow,
  IN HANDLE TmHandle OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtQueryInformationTransaction(
  IN HANDLE TransactionHandle,
  IN TRANSACTION_INFORMATION_CLASS TransactionInformationClass,
  OUT PVOID TransactionInformation,
  IN ULONG TransactionInformationLength,
  OUT PULONG ReturnLength OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtSetInformationTransaction(
  IN HANDLE TransactionHandle,
  IN TRANSACTION_INFORMATION_CLASS TransactionInformationClass,
  IN PVOID TransactionInformation,
  IN ULONG TransactionInformationLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtCommitTransaction(
  IN HANDLE TransactionHandle,
  IN BOOLEAN Wait);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtRollbackTransaction(
  IN HANDLE TransactionHandle,
  IN BOOLEAN Wait);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtCreateEnlistment(
  OUT PHANDLE EnlistmentHandle,
  IN ACCESS_MASK DesiredAccess,
  IN HANDLE ResourceManagerHandle,
  IN HANDLE TransactionHandle,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
  IN ULONG CreateOptions OPTIONAL,
  IN NOTIFICATION_MASK NotificationMask,
  IN PVOID EnlistmentKey OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtOpenEnlistment(
  OUT PHANDLE EnlistmentHandle,
  IN ACCESS_MASK DesiredAccess,
  IN HANDLE ResourceManagerHandle,
  IN LPGUID EnlistmentGuid,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtQueryInformationEnlistment(
  IN HANDLE EnlistmentHandle,
  IN ENLISTMENT_INFORMATION_CLASS EnlistmentInformationClass,
  OUT PVOID EnlistmentInformation,
  IN ULONG EnlistmentInformationLength,
  OUT PULONG ReturnLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtSetInformationEnlistment(
  IN HANDLE EnlistmentHandle OPTIONAL,
  IN ENLISTMENT_INFORMATION_CLASS EnlistmentInformationClass,
  IN PVOID EnlistmentInformation,
  IN ULONG EnlistmentInformationLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtRecoverEnlistment(
  IN HANDLE EnlistmentHandle,
  IN PVOID EnlistmentKey OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtPrePrepareEnlistment(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtPrepareEnlistment(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtCommitEnlistment(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtRollbackEnlistment(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtPrePrepareComplete(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtPrepareComplete(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtCommitComplete(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtReadOnlyEnlistment(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtRollbackComplete(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtSinglePhaseReject(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtCreateResourceManager(
  OUT PHANDLE ResourceManagerHandle,
  IN ACCESS_MASK DesiredAccess,
  IN HANDLE TmHandle,
  IN LPGUID RmGuid,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
  IN ULONG CreateOptions OPTIONAL,
  IN PUNICODE_STRING Description OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtOpenResourceManager(
  OUT PHANDLE ResourceManagerHandle,
  IN ACCESS_MASK DesiredAccess,
  IN HANDLE TmHandle,
  IN LPGUID ResourceManagerGuid OPTIONAL,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtRecoverResourceManager(
  IN HANDLE ResourceManagerHandle);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtGetNotificationResourceManager(
  IN HANDLE ResourceManagerHandle,
  OUT PTRANSACTION_NOTIFICATION TransactionNotification,
  IN ULONG NotificationLength,
  IN PLARGE_INTEGER Timeout OPTIONAL,
  OUT PULONG ReturnLength OPTIONAL,
  IN ULONG Asynchronous,
  IN ULONG_PTR AsynchronousContext OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtQueryInformationResourceManager(
  IN HANDLE ResourceManagerHandle,
  IN RESOURCEMANAGER_INFORMATION_CLASS ResourceManagerInformationClass,
  OUT PVOID ResourceManagerInformation,
  IN ULONG ResourceManagerInformationLength,
  OUT PULONG ReturnLength OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtSetInformationResourceManager(
  IN HANDLE ResourceManagerHandle,
  IN RESOURCEMANAGER_INFORMATION_CLASS ResourceManagerInformationClass,
  IN PVOID ResourceManagerInformation,
  IN ULONG ResourceManagerInformationLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtRegisterProtocolAddressInformation(
  IN HANDLE ResourceManager,
  IN PCRM_PROTOCOL_ID ProtocolId,
  IN ULONG ProtocolInformationSize,
  IN PVOID ProtocolInformation,
  IN ULONG CreateOptions OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtPropagationComplete(
  IN HANDLE ResourceManagerHandle,
  IN ULONG RequestCookie,
  IN ULONG BufferLength,
  IN PVOID Buffer);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtPropagationFailed(
  IN HANDLE ResourceManagerHandle,
  IN ULONG RequestCookie,
  IN NTSTATUS PropStatus);

#endif /* NTDDI_VERSION >= NTDDI_VISTA */

#endif /* !_NTTMAPI_ */

/******************************************************************************
 *                            ZwXxx Functions                                 *
 ******************************************************************************/

/* Constants */
#define NtCurrentProcess() ( (HANDLE)(LONG_PTR) -1 )
#define ZwCurrentProcess() NtCurrentProcess()
#define NtCurrentThread() ( (HANDLE)(LONG_PTR) -2 )
#define ZwCurrentThread() NtCurrentThread()


#if (NTDDI_VERSION >= NTDDI_WIN2K)

NTSYSAPI
NTSTATUS
NTAPI
ZwClose(
  IN HANDLE Handle);

NTSYSAPI
NTSTATUS
NTAPI
ZwCreateDirectoryObject(
  OUT PHANDLE DirectoryHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes);

NTSYSAPI
NTSTATUS
NTAPI
ZwCreateFile(
  OUT PHANDLE FileHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN PLARGE_INTEGER AllocationSize OPTIONAL,
  IN ULONG FileAttributes,
  IN ULONG ShareAccess,
  IN ULONG CreateDisposition,
  IN ULONG CreateOptions,
  IN PVOID EaBuffer OPTIONAL,
  IN ULONG EaLength);

NTSYSAPI
NTSTATUS
NTAPI
ZwCreateKey(
  OUT PHANDLE KeyHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes,
  IN ULONG TitleIndex,
  IN PUNICODE_STRING Class OPTIONAL,
  IN ULONG CreateOptions,
  OUT PULONG Disposition OPTIONAL);

NTSYSAPI
NTSTATUS
NTAPI
ZwCreateSection(
  OUT PHANDLE SectionHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
  IN PLARGE_INTEGER MaximumSize OPTIONAL,
  IN ULONG SectionPageProtection,
  IN ULONG AllocationAttributes,
  IN HANDLE FileHandle OPTIONAL);

NTSYSAPI
NTSTATUS
NTAPI
ZwDeleteKey(
  IN HANDLE KeyHandle);

NTSYSAPI
NTSTATUS
NTAPI
ZwDeleteValueKey(
  IN HANDLE KeyHandle,
  IN PUNICODE_STRING ValueName);

NTSYSAPI
NTSTATUS
NTAPI
ZwEnumerateKey(
  IN HANDLE KeyHandle,
  IN ULONG Index,
  IN KEY_INFORMATION_CLASS KeyInformationClass,
  OUT PVOID KeyInformation OPTIONAL,
  IN ULONG Length,
  OUT PULONG ResultLength);

NTSYSAPI
NTSTATUS
NTAPI
ZwEnumerateValueKey(
  IN HANDLE KeyHandle,
  IN ULONG Index,
  IN KEY_VALUE_INFORMATION_CLASS KeyValueInformationClass,
  OUT PVOID KeyValueInformation OPTIONAL,
  IN ULONG Length,
  OUT PULONG ResultLength);

NTSYSAPI
NTSTATUS
NTAPI
ZwFlushKey(
  IN HANDLE KeyHandle);

NTSYSAPI
NTSTATUS
NTAPI
ZwLoadDriver(
  IN PUNICODE_STRING DriverServiceName);

NTSYSAPI
NTSTATUS
NTAPI
ZwMakeTemporaryObject(
  IN HANDLE Handle);

NTSYSAPI
NTSTATUS
NTAPI
ZwMapViewOfSection(
  IN HANDLE SectionHandle,
  IN HANDLE ProcessHandle,
  IN OUT PVOID *BaseAddress,
  IN ULONG_PTR ZeroBits,
  IN SIZE_T CommitSize,
  IN OUT PLARGE_INTEGER SectionOffset OPTIONAL,
  IN OUT PSIZE_T ViewSize,
  IN SECTION_INHERIT InheritDisposition,
  IN ULONG AllocationType,
  IN ULONG Protect);

NTSYSAPI
NTSTATUS
NTAPI
ZwOpenFile(
  OUT PHANDLE FileHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN ULONG ShareAccess,
  IN ULONG OpenOptions);

NTSYSAPI
NTSTATUS
NTAPI
ZwOpenKey(
  OUT PHANDLE KeyHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes);

NTSYSAPI
NTSTATUS
NTAPI
ZwOpenSection(
  OUT PHANDLE SectionHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes);

NTSYSAPI
NTSTATUS
NTAPI
ZwOpenSymbolicLinkObject(
  OUT PHANDLE LinkHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes);

NTSYSAPI
NTSTATUS
NTAPI
ZwQueryInformationFile(
  IN HANDLE FileHandle,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  OUT PVOID FileInformation,
  IN ULONG Length,
  IN FILE_INFORMATION_CLASS FileInformationClass);

NTSYSAPI
NTSTATUS
NTAPI
ZwQueryKey(
  IN HANDLE KeyHandle,
  IN KEY_INFORMATION_CLASS KeyInformationClass,
  OUT PVOID KeyInformation OPTIONAL,
  IN ULONG Length,
  OUT PULONG ResultLength);

NTSYSAPI
NTSTATUS
NTAPI
ZwQuerySymbolicLinkObject(
  IN HANDLE LinkHandle,
  IN OUT PUNICODE_STRING LinkTarget,
  OUT PULONG ReturnedLength OPTIONAL);

NTSYSAPI
NTSTATUS
NTAPI
ZwQueryValueKey(
  IN HANDLE KeyHandle,
  IN PUNICODE_STRING ValueName,
  IN KEY_VALUE_INFORMATION_CLASS KeyValueInformationClass,
  OUT PVOID KeyValueInformation OPTIONAL,
  IN ULONG Length,
  OUT PULONG ResultLength);

NTSYSAPI
NTSTATUS
NTAPI
ZwReadFile(
  IN HANDLE FileHandle,
  IN HANDLE Event OPTIONAL,
  IN PIO_APC_ROUTINE ApcRoutine OPTIONAL,
  IN PVOID ApcContext OPTIONAL,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  OUT PVOID Buffer,
  IN ULONG Length,
  IN PLARGE_INTEGER ByteOffset OPTIONAL,
  IN PULONG Key OPTIONAL);

NTSYSAPI
NTSTATUS
NTAPI
ZwSetInformationFile(
  IN HANDLE FileHandle,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN PVOID FileInformation,
  IN ULONG Length,
  IN FILE_INFORMATION_CLASS FileInformationClass);

NTSYSAPI
NTSTATUS
NTAPI
ZwSetValueKey(
  IN HANDLE KeyHandle,
  IN PUNICODE_STRING ValueName,
  IN ULONG TitleIndex OPTIONAL,
  IN ULONG Type,
  IN PVOID Data OPTIONAL,
  IN ULONG DataSize);

NTSYSAPI
NTSTATUS
NTAPI
ZwUnloadDriver(
  IN PUNICODE_STRING DriverServiceName);

NTSYSAPI
NTSTATUS
NTAPI
ZwUnmapViewOfSection(
  IN HANDLE ProcessHandle,
  IN PVOID BaseAddress OPTIONAL);

NTSYSAPI
NTSTATUS
NTAPI
ZwWriteFile(
  IN HANDLE FileHandle,
  IN HANDLE Event OPTIONAL,
  IN PIO_APC_ROUTINE ApcRoutine OPTIONAL,
  IN PVOID ApcContext OPTIONAL,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN PVOID Buffer,
  IN ULONG Length,
  IN PLARGE_INTEGER ByteOffset OPTIONAL,
  IN PULONG Key OPTIONAL);

NTSYSAPI
NTSTATUS
NTAPI
ZwQueryFullAttributesFile(
  IN POBJECT_ATTRIBUTES ObjectAttributes,
  OUT PFILE_NETWORK_OPEN_INFORMATION FileInformation);

#endif /* (NTDDI_VERSION >= NTDDI_WIN2K) */


#if (NTDDI_VERSION >= NTDDI_WS03)
NTSYSCALLAPI
NTSTATUS
NTAPI
ZwOpenEvent(
  OUT PHANDLE EventHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes);
#endif

#if (NTDDI_VERSION >= NTDDI_VISTA)

NTSYSAPI
NTSTATUS
ZwCreateKeyTransacted(
  OUT PHANDLE KeyHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes,
  IN ULONG TitleIndex,
  IN PUNICODE_STRING Class OPTIONAL,
  IN ULONG CreateOptions,
  IN HANDLE TransactionHandle,
  OUT PULONG Disposition OPTIONAL);

NTSYSAPI
NTSTATUS
NTAPI
ZwOpenKeyTransacted(
  OUT PHANDLE KeyHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes,
  IN HANDLE TransactionHandle);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwCreateTransactionManager(
  OUT PHANDLE TmHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
  IN PUNICODE_STRING LogFileName OPTIONAL,
  IN ULONG CreateOptions OPTIONAL,
  IN ULONG CommitStrength OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwOpenTransactionManager(
  OUT PHANDLE TmHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
  IN PUNICODE_STRING LogFileName OPTIONAL,
  IN LPGUID TmIdentity OPTIONAL,
  IN ULONG OpenOptions OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwRollforwardTransactionManager(
  IN HANDLE TransactionManagerHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwRecoverTransactionManager(
  IN HANDLE TransactionManagerHandle);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwQueryInformationTransactionManager(
  IN HANDLE TransactionManagerHandle,
  IN TRANSACTIONMANAGER_INFORMATION_CLASS TransactionManagerInformationClass,
  OUT PVOID TransactionManagerInformation,
  IN ULONG TransactionManagerInformationLength,
  OUT PULONG ReturnLength OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwSetInformationTransactionManager(
  IN HANDLE TmHandle,
  IN TRANSACTIONMANAGER_INFORMATION_CLASS TransactionManagerInformationClass,
  IN PVOID TransactionManagerInformation,
  IN ULONG TransactionManagerInformationLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwEnumerateTransactionObject(
  IN HANDLE RootObjectHandle OPTIONAL,
  IN KTMOBJECT_TYPE QueryType,
  IN OUT PKTMOBJECT_CURSOR ObjectCursor,
  IN ULONG ObjectCursorLength,
  OUT PULONG ReturnLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwCreateTransaction(
  OUT PHANDLE TransactionHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
  IN LPGUID Uow OPTIONAL,
  IN HANDLE TmHandle OPTIONAL,
  IN ULONG CreateOptions OPTIONAL,
  IN ULONG IsolationLevel OPTIONAL,
  IN ULONG IsolationFlags OPTIONAL,
  IN PLARGE_INTEGER Timeout OPTIONAL,
  IN PUNICODE_STRING Description OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwOpenTransaction(
  OUT PHANDLE TransactionHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
  IN LPGUID Uow,
  IN HANDLE TmHandle OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwQueryInformationTransaction(
  IN HANDLE TransactionHandle,
  IN TRANSACTION_INFORMATION_CLASS TransactionInformationClass,
  OUT PVOID TransactionInformation,
  IN ULONG TransactionInformationLength,
  OUT PULONG ReturnLength OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwSetInformationTransaction(
  IN HANDLE TransactionHandle,
  IN TRANSACTION_INFORMATION_CLASS TransactionInformationClass,
  IN PVOID TransactionInformation,
  IN ULONG TransactionInformationLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwCommitTransaction(
  IN HANDLE TransactionHandle,
  IN BOOLEAN Wait);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwRollbackTransaction(
  IN HANDLE TransactionHandle,
  IN BOOLEAN Wait);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwCreateResourceManager(
  OUT PHANDLE ResourceManagerHandle,
  IN ACCESS_MASK DesiredAccess,
  IN HANDLE TmHandle,
  IN LPGUID ResourceManagerGuid OPTIONAL,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
  IN ULONG CreateOptions OPTIONAL,
  IN PUNICODE_STRING Description OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwOpenResourceManager(
  OUT PHANDLE ResourceManagerHandle,
  IN ACCESS_MASK DesiredAccess,
  IN HANDLE TmHandle,
  IN LPGUID ResourceManagerGuid,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwRecoverResourceManager(
  IN HANDLE ResourceManagerHandle);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwGetNotificationResourceManager(
  IN HANDLE ResourceManagerHandle,
  OUT PTRANSACTION_NOTIFICATION TransactionNotification,
  IN ULONG NotificationLength,
  IN PLARGE_INTEGER Timeout,
  IN PULONG ReturnLength OPTIONAL,
  IN ULONG Asynchronous,
  IN ULONG_PTR AsynchronousContext OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwQueryInformationResourceManager(
  IN HANDLE ResourceManagerHandle,
  IN RESOURCEMANAGER_INFORMATION_CLASS ResourceManagerInformationClass,
  OUT PVOID ResourceManagerInformation,
  IN ULONG ResourceManagerInformationLength,
  IN PULONG ReturnLength OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwSetInformationResourceManager(
  IN HANDLE ResourceManagerHandle,
  IN RESOURCEMANAGER_INFORMATION_CLASS ResourceManagerInformationClass,
  IN PVOID ResourceManagerInformation,
  IN ULONG ResourceManagerInformationLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwCreateEnlistment(
  OUT PHANDLE EnlistmentHandle,
  IN ACCESS_MASK DesiredAccess,
  IN HANDLE ResourceManagerHandle,
  IN HANDLE TransactionHandle,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
  IN ULONG CreateOptions OPTIONAL,
  IN NOTIFICATION_MASK NotificationMask,
  IN PVOID EnlistmentKey OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwOpenEnlistment(
  OUT PHANDLE EnlistmentHandle,
  IN ACCESS_MASK DesiredAccess,
  IN HANDLE RmHandle,
  IN LPGUID EnlistmentGuid,
  IN POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwQueryInformationEnlistment(
  IN HANDLE EnlistmentHandle,
  IN ENLISTMENT_INFORMATION_CLASS EnlistmentInformationClass,
  OUT PVOID EnlistmentInformation,
  IN ULONG EnlistmentInformationLength,
  IN PULONG ReturnLength OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwSetInformationEnlistment(
  IN HANDLE EnlistmentHandle,
  IN ENLISTMENT_INFORMATION_CLASS EnlistmentInformationClass,
  IN PVOID EnlistmentInformation,
  IN ULONG EnlistmentInformationLength);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwRecoverEnlistment(
  IN HANDLE EnlistmentHandle,
  IN PVOID EnlistmentKey OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwPrePrepareEnlistment(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwPrepareEnlistment(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwCommitEnlistment(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwRollbackEnlistment(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwPrePrepareComplete(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwPrepareComplete(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwCommitComplete(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwReadOnlyEnlistment(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwRollbackComplete(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);

NTSYSCALLAPI
NTSTATUS
NTAPI
ZwSinglePhaseReject(
  IN HANDLE EnlistmentHandle,
  IN PLARGE_INTEGER TmVirtualClock OPTIONAL);
#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#if (NTDDI_VERSION >= NTDDI_WIN7)
NTSYSAPI
NTSTATUS
NTAPI
ZwOpenKeyEx(
  OUT PHANDLE KeyHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes,
  IN ULONG OpenOptions);

NTSYSAPI
NTSTATUS
NTAPI
ZwOpenKeyTransactedEx(
  OUT PHANDLE KeyHandle,
  IN ACCESS_MASK DesiredAccess,
  IN POBJECT_ATTRIBUTES ObjectAttributes,
  IN ULONG OpenOptions,
  IN HANDLE TransactionHandle);

NTSYSAPI
NTSTATUS
NTAPI
ZwNotifyChangeMultipleKeys(
  IN HANDLE MasterKeyHandle,
  IN ULONG Count OPTIONAL,
  IN OBJECT_ATTRIBUTES SubordinateObjects[] OPTIONAL,
  IN HANDLE Event OPTIONAL,
  IN PIO_APC_ROUTINE ApcRoutine OPTIONAL,
  IN PVOID ApcContext OPTIONAL,
  OUT PIO_STATUS_BLOCK IoStatusBlock,
  IN ULONG CompletionFilter,
  IN BOOLEAN WatchTree,
  OUT PVOID Buffer OPTIONAL,
  IN ULONG BufferSize,
  IN BOOLEAN Asynchronous);

NTSYSAPI
NTSTATUS
NTAPI
ZwQueryMultipleValueKey(
  IN HANDLE KeyHandle,
  IN OUT PKEY_VALUE_ENTRY ValueEntries,
  IN ULONG EntryCount,
  OUT PVOID ValueBuffer,
  IN OUT PULONG BufferLength,
  OUT PULONG RequiredBufferLength OPTIONAL);

NTSYSAPI
NTSTATUS
NTAPI
ZwRenameKey(
  IN HANDLE KeyHandle,
  IN PUNICODE_STRING NewName);

NTSYSAPI
NTSTATUS
NTAPI
ZwSetInformationKey(
  IN HANDLE KeyHandle,
  IN KEY_SET_INFORMATION_CLASS KeySetInformationClass,
  IN PVOID KeySetInformation,
  IN ULONG KeySetInformationLength);

#endif /* (NTDDI_VERSION >= NTDDI_WIN7) */

#ifdef __cplusplus
}
#endif

#endif /* !_WDMDDK_ */
