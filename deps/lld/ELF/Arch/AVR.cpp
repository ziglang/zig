//===- AVR.cpp ------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// AVR is a Harvard-architecture 8-bit micrcontroller designed for small
// baremetal programs. All AVR-family processors have 32 8-bit registers.
// The tiniest AVR has 32 byte RAM and 1 KiB program memory, and the largest
// one supports up to 2^24 data address space and 2^22 code address space.
//
// Since it is a baremetal programming, there's usually no loader to load
// ELF files on AVRs. You are expected to link your program against address
// 0 and pull out a .text section from the result using objcopy, so that you
// can write the linked code to on-chip flush memory. You can do that with
// the following commands:
//
//   ld.lld -Ttext=0 -o foo foo.o
//   objcopy -O binary --only-section=.text foo output.bin
//
// Note that the current AVR support is very preliminary so you can't
// link any useful program yet, though.
//
//===----------------------------------------------------------------------===//

#include "InputFiles.h"
#include "Symbols.h"
#include "Target.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/Object/ELF.h"
#include "llvm/Support/Endian.h"

using namespace llvm;
using namespace llvm::object;
using namespace llvm::support::endian;
using namespace llvm::ELF;
using namespace lld;
using namespace lld::elf;

namespace {
class AVR final : public TargetInfo {
public:
  AVR();
  RelExpr getRelExpr(RelType type, const Symbol &s,
                     const uint8_t *loc) const override;
  void relocateOne(uint8_t *loc, RelType type, uint64_t val) const override;
};
} // namespace

AVR::AVR() { noneRel = R_AVR_NONE; }

RelExpr AVR::getRelExpr(RelType type, const Symbol &s,
                        const uint8_t *loc) const {
  return R_ABS;
}

void AVR::relocateOne(uint8_t *loc, RelType type, uint64_t val) const {
  switch (type) {
  case R_AVR_CALL: {
    uint16_t hi = val >> 17;
    uint16_t lo = val >> 1;
    write16le(loc, read16le(loc) | ((hi >> 1) << 4) | (hi & 1));
    write16le(loc + 2, lo);
    break;
  }
  default:
    error(getErrorLocation(loc) + "unrecognized relocation " + toString(type));
  }
}

TargetInfo *elf::getAVRTargetInfo() {
  static AVR target;
  return &target;
}
