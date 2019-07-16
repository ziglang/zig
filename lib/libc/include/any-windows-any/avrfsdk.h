/**
* This file is part of the mingw-w64 runtime package.
* No warranty is given; refer to the file DISCLAIMER within this package.
*/

#include <winapifamily.h>

#ifndef _AVRFSDK_
#define _AVRFSDK_

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#ifdef __cplusplus
extern "C" {
#endif

#define AVRF_MAX_TRACES 32

  enum eHeapAllocationState {
    HeapFullPageHeap = 0x40000000,
    HeapMetadata = 0x80000000,
    HeapStateMask = 0xffff0000
  };

  enum eHeapEnumerationLevel {
    HeapEnumerationEverything = 0x0,
    HeapEnumerationStop = 0xffffffff
  };

  enum eHANDLE_TRACE_OPERATIONS {
    OperationDbUnused,
    OperationDbOPEN,
    OperationDbCLOSE,
    OperationDbBADREF
  };

  enum eAvrfResourceTypes {
    AvrfResourceHeapAllocation,
    AvrfResourceHandleTrace,
    AvrfResourceMax
  };

  enum eUserAllocationState {
    AllocationStateUnknown,
    AllocationStateBusy,
    AllocationStateFree
  };

  typedef struct _AVRF_BACKTRACE_INFORMATION {
    ULONG Depth;
    ULONG Index;
    ULONG64 ReturnAddresses[AVRF_MAX_TRACES];
  } AVRF_BACKTRACE_INFORMATION,*PAVRF_BACKTRACE_INFORMATION;

  typedef struct _AVRF_HEAP_ALLOCATION {
    ULONG64 HeapHandle;
    ULONG64 UserAllocation;
    ULONG64 UserAllocationSize;
    ULONG64 Allocation;
    ULONG64 AllocationSize;
    ULONG UserAllocationState;
    ULONG HeapState;
    ULONG64 HeapContext;
    PAVRF_BACKTRACE_INFORMATION BackTraceInformation;
  } AVRF_HEAP_ALLOCATION,*PAVRF_HEAP_ALLOCATION;

  typedef struct _AVRF_HANDLE_OPERATION {
    ULONG64 Handle;
    ULONG ProcessId;
    ULONG ThreadId;
    ULONG OperationType;
    ULONG Spare0;
    AVRF_BACKTRACE_INFORMATION BackTraceInformation;
  } AVRF_HANDLE_OPERATION,*PAVRF_HANDLE_OPERATION;

  typedef ULONG (NTAPI *AVRF_RESOURCE_ENUMERATE_CALLBACK) (PVOID ResourceDescription, PVOID EnumerationContext, PULONG EnumerationLevel);
  typedef ULONG (NTAPI *AVRF_HEAPALLOCATION_ENUMERATE_CALLBACK) (PAVRF_HEAP_ALLOCATION HeapAllocation, PVOID EnumerationContext, PULONG EnumerationLevel);
  typedef ULONG (NTAPI *AVRF_HANDLEOPERATION_ENUMERATE_CALLBACK) (PAVRF_HANDLE_OPERATION HandleOperation, PVOID EnumerationContext, PULONG EnumerationLevel);

#define AVRF_ENUM_RESOURCES_FLAGS_SUSPEND 0x0001
#define AVRF_ENUM_RESOURCES_FLAGS_DONT_RESOLVE_TRACES 0x0002

  ULONG NTAPI VerifierEnumerateResource (HANDLE Process, ULONG Flags, ULONG ResourceType, AVRF_RESOURCE_ENUMERATE_CALLBACK ResourceCallback, PVOID EnumerationContext);
  WINBOOL NTAPI VerifierIsPerUserSettingsEnabled (VOID);

#ifdef __cplusplus
}
#endif

#endif
#endif
