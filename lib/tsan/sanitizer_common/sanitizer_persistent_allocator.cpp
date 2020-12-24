//===-- sanitizer_persistent_allocator.cpp ----------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file is shared between AddressSanitizer and ThreadSanitizer
// run-time libraries.
//===----------------------------------------------------------------------===//
#include "sanitizer_persistent_allocator.h"

namespace __sanitizer {

PersistentAllocator thePersistentAllocator;

}  // namespace __sanitizer
