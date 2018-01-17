//===- OutputSegment.h ------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_WASM_OUTPUT_SEGMENT_H
#define LLD_WASM_OUTPUT_SEGMENT_H

#include "InputSegment.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/Object/Wasm.h"

namespace lld {
namespace wasm {

class InputSegment;

class OutputSegment {
public:
  OutputSegment(StringRef N) : Name(N) {}

  void addInputSegment(InputSegment *Segment) {
    Alignment = std::max(Alignment, Segment->getAlignment());
    InputSegments.push_back(Segment);
    Size = llvm::alignTo(Size, Segment->getAlignment());
    Segment->setOutputSegment(this, Size);
    Size += Segment->getSize();
  }

  uint32_t getSectionOffset() const { return SectionOffset; }

  void setSectionOffset(uint32_t Offset) { SectionOffset = Offset; }

  StringRef Name;
  uint32_t Alignment = 0;
  uint32_t StartVA = 0;
  std::vector<InputSegment *> InputSegments;

  // Sum of the size of the all the input segments
  uint32_t Size = 0;

  // Segment header
  std::string Header;

private:
  uint32_t SectionOffset = 0;
};

} // namespace wasm
} // namespace lld

#endif // LLD_WASM_OUTPUT_SEGMENT_H
