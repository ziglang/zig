//===-- sanitizer_thread_safety.h -------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file is shared between sanitizer tools.
//
// Wrappers around thread safety annotations.
// https://clang.llvm.org/docs/ThreadSafetyAnalysis.html
//===----------------------------------------------------------------------===//

#ifndef SANITIZER_THREAD_SAFETY_H
#define SANITIZER_THREAD_SAFETY_H

#if defined(__clang__)
#  define THREAD_ANNOTATION(x) __attribute__((x))
#else
#  define THREAD_ANNOTATION(x)
#endif

#define MUTEX THREAD_ANNOTATION(capability("mutex"))
#define SCOPED_LOCK THREAD_ANNOTATION(scoped_lockable)
#define GUARDED_BY(x) THREAD_ANNOTATION(guarded_by(x))
#define PT_GUARDED_BY(x) THREAD_ANNOTATION(pt_guarded_by(x))
#define REQUIRES(...) THREAD_ANNOTATION(requires_capability(__VA_ARGS__))
#define REQUIRES_SHARED(...) \
  THREAD_ANNOTATION(requires_shared_capability(__VA_ARGS__))
#define ACQUIRE(...) THREAD_ANNOTATION(acquire_capability(__VA_ARGS__))
#define ACQUIRE_SHARED(...) \
  THREAD_ANNOTATION(acquire_shared_capability(__VA_ARGS__))
#define TRY_ACQUIRE(...) THREAD_ANNOTATION(try_acquire_capability(__VA_ARGS__))
#define RELEASE(...) THREAD_ANNOTATION(release_capability(__VA_ARGS__))
#define RELEASE_SHARED(...) \
  THREAD_ANNOTATION(release_shared_capability(__VA_ARGS__))
#define EXCLUDES(...) THREAD_ANNOTATION(locks_excluded(__VA_ARGS__))
#define CHECK_LOCKED(...) THREAD_ANNOTATION(assert_capability(__VA_ARGS__))
#define NO_THREAD_SAFETY_ANALYSIS THREAD_ANNOTATION(no_thread_safety_analysis)

#endif
