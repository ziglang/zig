/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _APISET_IORING_
#define _APISET_IORING_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>
#include <ntioring_x.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP)
#if NTDDI_VERSION >= NTDDI_WIN10_CO

DECLARE_HANDLE(HIORING);

typedef enum IORING_SQE_FLAGS {
  IOSQE_FLAGS_NONE = 0
} IORING_SQE_FLAGS;
DEFINE_ENUM_FLAG_OPERATORS(IORING_SQE_FLAGS)

typedef enum IORING_CREATE_REQUIRED_FLAGS {
  IORING_CREATE_REQUIRED_FLAGS_NONE = 0
} IORING_CREATE_REQUIRED_FLAGS;
DEFINE_ENUM_FLAG_OPERATORS(IORING_CREATE_REQUIRED_FLAGS)

typedef enum IORING_CREATE_ADVISORY_FLAGS {
  IORING_CREATE_ADVISORY_FLAGS_NONE = 0
} IORING_CREATE_ADVISORY_FLAGS;
DEFINE_ENUM_FLAG_OPERATORS(IORING_CREATE_ADVISORY_FLAGS)

typedef struct IORING_CREATE_FLAGS {
  IORING_CREATE_REQUIRED_FLAGS Required;
  IORING_CREATE_ADVISORY_FLAGS Advisory;
} IORING_CREATE_FLAGS;

typedef struct IORING_INFO {
  IORING_VERSION IoRingVersion;
  IORING_CREATE_FLAGS Flags;
  UINT32 SubmissionQueueSize;
  UINT32 CompletionQueueSize;
} IORING_INFO;

typedef struct IORING_CAPABILITIES {
  IORING_VERSION MaxVersion;
  UINT32 MaxSubmissionQueueSize;
  UINT32 MaxCompletionQueueSize;
  IORING_FEATURE_FLAGS FeatureFlags;
} IORING_CAPABILITIES;

typedef enum IORING_REF_KIND {
  IORING_REF_RAW,
  IORING_REF_REGISTERED
} IORING_REF_KIND;

typedef struct IORING_HANDLE_REF {
#ifdef __cplusplus
  explicit IORING_HANDLE_REF(HANDLE h) : Kind(IORING_REF_KIND::IORING_REF_RAW), Handle(h) {}
  explicit IORING_HANDLE_REF(UINT32 index) : Kind(IORING_REF_KIND::IORING_REF_REGISTERED), Handle(index) {}
#endif

  IORING_REF_KIND Kind;
  union HandleUnion {
#ifdef __cplusplus
    HandleUnion(HANDLE h) : Handle(h) {}
    HandleUnion(UINT32 index) : Index(index) {}
#endif
    HANDLE Handle;
    UINT32 Index;
  } Handle;
} IORING_HANDLE_REF;

#ifdef __cplusplus
#define IoRingHandleRefFromHandle(h) IORING_HANDLE_REF(static_cast<HANDLE>(h))
#define IoRingHandleRefFromIndex(i) IORING_HANDLE_REF(static_cast<UINT32>(i))
#else
#define IoRingHandleRefFromHandle(h) {IORING_REF_RAW, {.Handle = h}}
#define IoRingHandleRefFromIndex(i) {IORING_REF_REGISTERED, {.Index = i}}
#endif

typedef struct IORING_BUFFER_REF {
#ifdef __cplusplus
  explicit IORING_BUFFER_REF(void* address) : Kind(IORING_REF_KIND::IORING_REF_RAW), Buffer(address) {}
  explicit IORING_BUFFER_REF(IORING_REGISTERED_BUFFER registeredBuffer) : Kind(IORING_REF_KIND::IORING_REF_REGISTERED), Buffer(registeredBuffer) {}
  IORING_BUFFER_REF(UINT32 index, UINT32 offset) : IORING_BUFFER_REF(IORING_REGISTERED_BUFFER{index, offset}) {}
#endif

  IORING_REF_KIND Kind;
  union BufferUnion {
#ifdef __cplusplus
    BufferUnion(void* address) : Address(address) {}
    BufferUnion(IORING_REGISTERED_BUFFER indexAndOffset) : IndexAndOffset(indexAndOffset) {}
#endif
    void* Address;
    IORING_REGISTERED_BUFFER IndexAndOffset;
  }Buffer;
} IORING_BUFFER_REF;

#ifdef __cplusplus
#define IoRingBufferRefFromPointer(p) IORING_BUFFER_REF(static_cast<void*>(p))
#define IoRingBufferRefFromIndexAndOffset(i,o) IORING_BUFFER_REF((i),(o))
#else
#define IoRingBufferRefFromPointer(p) {IORING_REF_RAW, {.Address = p}}
#define IoRingBufferRefFromIndexAndOffset(i,o) {IORING_REF_REGISTERED, {.IndexAndOffset = {(i),(o)}}}
#endif

typedef struct IORING_CQE {
  UINT_PTR UserData;
  HRESULT ResultCode;
  ULONG_PTR Information;
} IORING_CQE;

#ifdef __cplusplus
extern "C" {
#endif

STDAPI QueryIoRingCapabilities(IORING_CAPABILITIES* capabilities);
STDAPI_(WINBOOL) IsIoRingOpSupported(HIORING ioRing, IORING_OP_CODE op);
STDAPI CreateIoRing(IORING_VERSION ioringVersion, IORING_CREATE_FLAGS flags, UINT32 submissionQueueSize, UINT32 completionQueueSize, HIORING* h);
STDAPI GetIoRingInfo(HIORING ioRing, IORING_INFO* info);
STDAPI SubmitIoRing(HIORING ioRing, UINT32 waitOperations, UINT32 milliseconds, UINT32* submittedEntries);
STDAPI CloseIoRing(HIORING ioRing);
STDAPI PopIoRingCompletion(HIORING ioRing, IORING_CQE* cqe);
STDAPI SetIoRingCompletionEvent(HIORING ioRing, HANDLE hEvent);
STDAPI BuildIoRingCancelRequest(HIORING ioRing, IORING_HANDLE_REF file, UINT_PTR opToCancel, UINT_PTR userData);
STDAPI BuildIoRingReadFile(HIORING ioRing, IORING_HANDLE_REF fileRef, IORING_BUFFER_REF dataRef, UINT32 numberOfBytesToRead, UINT64 fileOffset, UINT_PTR userData, IORING_SQE_FLAGS flags);
STDAPI BuildIoRingRegisterFileHandles(HIORING ioRing, UINT32 count, HANDLE const handles[], UINT_PTR userData);
STDAPI BuildIoRingRegisterBuffers(HIORING ioRing, UINT32 count, IORING_BUFFER_INFO const buffers[], UINT_PTR userData);

#ifdef __cplusplus
}
#endif

#endif /* NTDDI_WIN10_CO */
#endif /* WINAPI_PARTITION_APP */
#endif /* _APISET_IORING_ */
