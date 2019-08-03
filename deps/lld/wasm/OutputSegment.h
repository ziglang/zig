//===- OutputSegment.h ------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_WASM_OUTPUT_SEGMENT_H
#define LLD_WASM_OUTPUT_SEGMENT_H

#include "InputChunks.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/Object/Wasm.h"

namespace lld {
namespace wasm {

class InputSegment;

class OutputSegment {
public:
  OutputSegment(StringRef n, uint32_t index) : name(n), index(index) {}

  void addInputSegment(InputSegment *inSeg) {
    alignment = std::max(alignment, inSeg->getAlignment());
    inputSegments.push_back(inSeg);
    size = llvm::alignTo(size, 1ULL << inSeg->getAlignment());
    inSeg->outputSeg = this;
    inSeg->outputSegmentOffset = size;
    size += inSeg->getSize();
  }

  StringRef name;
  const uint32_t index;
  uint32_t initFlags = 0;
  uint32_t sectionOffset = 0;
  uint32_t alignment = 0;
  uint32_t startVA = 0;
  std::vector<InputSegment *> inputSegments;

  // Sum of the size of the all the input segments
  uint32_t size = 0;

  // Segment header
  std::string header;
};

} // namespace wasm
} // namespace lld

#endif // LLD_WASM_OUTPUT_SEGMENT_H
