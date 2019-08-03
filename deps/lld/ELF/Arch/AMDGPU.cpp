//===- AMDGPU.cpp ---------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
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
class AMDGPU final : public TargetInfo {
public:
  AMDGPU();
  uint32_t calcEFlags() const override;
  void relocateOne(uint8_t *loc, RelType type, uint64_t val) const override;
  RelExpr getRelExpr(RelType type, const Symbol &s,
                     const uint8_t *loc) const override;
  RelType getDynRel(RelType type) const override;
};
} // namespace

AMDGPU::AMDGPU() {
  relativeRel = R_AMDGPU_RELATIVE64;
  gotRel = R_AMDGPU_ABS64;
  noneRel = R_AMDGPU_NONE;
  symbolicRel = R_AMDGPU_ABS64;
}

static uint32_t getEFlags(InputFile *file) {
  return cast<ObjFile<ELF64LE>>(file)->getObj().getHeader()->e_flags;
}

uint32_t AMDGPU::calcEFlags() const {
  assert(!objectFiles.empty());
  uint32_t ret = getEFlags(objectFiles[0]);

  // Verify that all input files have the same e_flags.
  for (InputFile *f : makeArrayRef(objectFiles).slice(1)) {
    if (ret == getEFlags(f))
      continue;
    error("incompatible e_flags: " + toString(f));
    return 0;
  }
  return ret;
}

void AMDGPU::relocateOne(uint8_t *loc, RelType type, uint64_t val) const {
  switch (type) {
  case R_AMDGPU_ABS32:
  case R_AMDGPU_GOTPCREL:
  case R_AMDGPU_GOTPCREL32_LO:
  case R_AMDGPU_REL32:
  case R_AMDGPU_REL32_LO:
    write32le(loc, val);
    break;
  case R_AMDGPU_ABS64:
  case R_AMDGPU_REL64:
    write64le(loc, val);
    break;
  case R_AMDGPU_GOTPCREL32_HI:
  case R_AMDGPU_REL32_HI:
    write32le(loc, val >> 32);
    break;
  default:
    llvm_unreachable("unknown relocation");
  }
}

RelExpr AMDGPU::getRelExpr(RelType type, const Symbol &s,
                           const uint8_t *loc) const {
  switch (type) {
  case R_AMDGPU_ABS32:
  case R_AMDGPU_ABS64:
    return R_ABS;
  case R_AMDGPU_REL32:
  case R_AMDGPU_REL32_LO:
  case R_AMDGPU_REL32_HI:
  case R_AMDGPU_REL64:
    return R_PC;
  case R_AMDGPU_GOTPCREL:
  case R_AMDGPU_GOTPCREL32_LO:
  case R_AMDGPU_GOTPCREL32_HI:
    return R_GOT_PC;
  default:
    error(getErrorLocation(loc) + "unknown relocation (" + Twine(type) +
          ") against symbol " + toString(s));
    return R_NONE;
  }
}

RelType AMDGPU::getDynRel(RelType type) const {
  if (type == R_AMDGPU_ABS64)
    return type;
  return R_AMDGPU_NONE;
}

TargetInfo *elf::getAMDGPUTargetInfo() {
  static AMDGPU target;
  return &target;
}
