//===- PPC.cpp ------------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "Error.h"
#include "Symbols.h"
#include "Target.h"
#include "llvm/Support/Endian.h"

using namespace llvm;
using namespace llvm::support::endian;
using namespace llvm::ELF;
using namespace lld;
using namespace lld::elf;

namespace {
class PPC final : public TargetInfo {
public:
  PPC() { GotBaseSymOff = 0x8000; }
  void relocateOne(uint8_t *Loc, uint32_t Type, uint64_t Val) const override;
  RelExpr getRelExpr(uint32_t Type, const SymbolBody &S,
                     const uint8_t *Loc) const override;
};
} // namespace

void PPC::relocateOne(uint8_t *Loc, uint32_t Type, uint64_t Val) const {
  switch (Type) {
  case R_PPC_ADDR16_HA:
    write16be(Loc, (Val + 0x8000) >> 16);
    break;
  case R_PPC_ADDR16_LO:
    write16be(Loc, Val);
    break;
  case R_PPC_ADDR32:
  case R_PPC_REL32:
    write32be(Loc, Val);
    break;
  case R_PPC_REL24:
    write32be(Loc, read32be(Loc) | (Val & 0x3FFFFFC));
    break;
  default:
    error(getErrorLocation(Loc) + "unrecognized reloc " + Twine(Type));
  }
}

RelExpr PPC::getRelExpr(uint32_t Type, const SymbolBody &S,
                        const uint8_t *Loc) const {
  switch (Type) {
  case R_PPC_REL24:
  case R_PPC_REL32:
    return R_PC;
  default:
    return R_ABS;
  }
}

TargetInfo *elf::getPPCTargetInfo() {
  static PPC Target;
  return &Target;
}
