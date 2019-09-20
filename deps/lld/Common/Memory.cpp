//===- Memory.cpp ---------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "lld/Common/Memory.h"

using namespace llvm;
using namespace lld;

BumpPtrAllocator lld::bAlloc;
StringSaver lld::saver{bAlloc};
std::vector<SpecificAllocBase *> lld::SpecificAllocBase::instances;

void lld::freeArena() {
  for (SpecificAllocBase *alloc : SpecificAllocBase::instances)
    alloc->reset();
  bAlloc.Reset();
}
