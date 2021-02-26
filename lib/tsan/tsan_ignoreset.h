//===-- tsan_ignoreset.h ----------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file is a part of ThreadSanitizer (TSan), a race detector.
//
// IgnoreSet holds a set of stack traces where ignores were enabled.
//===----------------------------------------------------------------------===//
#ifndef TSAN_IGNORESET_H
#define TSAN_IGNORESET_H

#include "tsan_defs.h"

namespace __tsan {

class IgnoreSet {
 public:
  static const uptr kMaxSize = 16;

  IgnoreSet();
  void Add(u32 stack_id);
  void Reset();
  uptr Size() const;
  u32 At(uptr i) const;

 private:
  uptr size_;
  u32 stacks_[kMaxSize];
};

}  // namespace __tsan

#endif  // TSAN_IGNORESET_H
