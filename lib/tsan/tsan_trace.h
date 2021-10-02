//===-- tsan_trace.h --------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file is a part of ThreadSanitizer (TSan), a race detector.
//
//===----------------------------------------------------------------------===//
#ifndef TSAN_TRACE_H
#define TSAN_TRACE_H

#include "tsan_defs.h"
#include "tsan_stack_trace.h"
#include "tsan_mutexset.h"

namespace __tsan {

const int kTracePartSizeBits = 13;
const int kTracePartSize = 1 << kTracePartSizeBits;
const int kTraceParts = 2 * 1024 * 1024 / kTracePartSize;
const int kTraceSize = kTracePartSize * kTraceParts;

// Must fit into 3 bits.
enum EventType {
  EventTypeMop,
  EventTypeFuncEnter,
  EventTypeFuncExit,
  EventTypeLock,
  EventTypeUnlock,
  EventTypeRLock,
  EventTypeRUnlock
};

// Represents a thread event (from most significant bit):
// u64 typ  : 3;   // EventType.
// u64 addr : 61;  // Associated pc.
typedef u64 Event;

const uptr kEventPCBits = 61;

struct TraceHeader {
#if !SANITIZER_GO
  BufferedStackTrace stack0;  // Start stack for the trace.
#else
  VarSizeStackTrace stack0;
#endif
  u64        epoch0;  // Start epoch for the trace.
  MutexSet   mset0;

  TraceHeader() : stack0(), epoch0() {}
};

struct Trace {
  Mutex mtx;
#if !SANITIZER_GO
  // Must be last to catch overflow as paging fault.
  // Go shadow stack is dynamically allocated.
  uptr shadow_stack[kShadowStackSize];
#endif
  // Must be the last field, because we unmap the unused part in
  // CreateThreadContext.
  TraceHeader headers[kTraceParts];

  Trace() : mtx(MutexTypeTrace) {}
};

}  // namespace __tsan

#endif  // TSAN_TRACE_H
