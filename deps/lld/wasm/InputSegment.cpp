//===- InputSegment.cpp ---------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "InputSegment.h"
#include "OutputSegment.h"
#include "lld/Common/LLVM.h"

#define DEBUG_TYPE "lld"

using namespace llvm;
using namespace lld::wasm;

uint32_t InputSegment::translateVA(uint32_t Address) const {
  assert(Address >= startVA() && Address < endVA());
  int32_t Delta = OutputSeg->StartVA + OutputSegmentOffset - startVA();
  DEBUG(dbgs() << "translateVA: " << getName() << " Delta=" << Delta
               << " Address=" << Address << "\n");
  return Address + Delta;
}
