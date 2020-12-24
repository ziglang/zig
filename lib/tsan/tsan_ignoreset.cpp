//===-- tsan_ignoreset.cpp ------------------------------------------------===//
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
#include "tsan_ignoreset.h"

namespace __tsan {

const uptr IgnoreSet::kMaxSize;

IgnoreSet::IgnoreSet()
    : size_() {
}

void IgnoreSet::Add(u32 stack_id) {
  if (size_ == kMaxSize)
    return;
  for (uptr i = 0; i < size_; i++) {
    if (stacks_[i] == stack_id)
      return;
  }
  stacks_[size_++] = stack_id;
}

void IgnoreSet::Reset() {
  size_ = 0;
}

uptr IgnoreSet::Size() const {
  return size_;
}

u32 IgnoreSet::At(uptr i) const {
  CHECK_LT(i, size_);
  CHECK_LE(size_, kMaxSize);
  return stacks_[i];
}

}  // namespace __tsan
