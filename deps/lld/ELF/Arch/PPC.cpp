//===- PPC.cpp ------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "OutputSections.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/Support/Endian.h"

using namespace llvm;
using namespace llvm::support::endian;
using namespace llvm::ELF;
using namespace lld;
using namespace lld::elf;

namespace {
class PPC final : public TargetInfo {
public:
  PPC();
  RelExpr getRelExpr(RelType type, const Symbol &s,
                     const uint8_t *loc) const override;
  RelType getDynRel(RelType type) const override;
  void writeGotHeader(uint8_t *buf) const override;
  void writePltHeader(uint8_t *buf) const override {
    llvm_unreachable("should call writePPC32GlinkSection() instead");
  }
  void writePlt(uint8_t *buf, uint64_t gotPltEntryAddr, uint64_t pltEntryAddr,
    int32_t index, unsigned relOff) const override {
    llvm_unreachable("should call writePPC32GlinkSection() instead");
  }
  void writeGotPlt(uint8_t *buf, const Symbol &s) const override;
  bool needsThunk(RelExpr expr, RelType relocType, const InputFile *file,
                  uint64_t branchAddr, const Symbol &s) const override;
  uint32_t getThunkSectionSpacing() const override;
  bool inBranchRange(RelType type, uint64_t src, uint64_t dst) const override;
  void relocateOne(uint8_t *loc, RelType type, uint64_t val) const override;
  RelExpr adjustRelaxExpr(RelType type, const uint8_t *data,
                          RelExpr expr) const override;
  int getTlsGdRelaxSkip(RelType type) const override;
  void relaxTlsGdToIe(uint8_t *loc, RelType type, uint64_t val) const override;
  void relaxTlsGdToLe(uint8_t *loc, RelType type, uint64_t val) const override;
  void relaxTlsLdToLe(uint8_t *loc, RelType type, uint64_t val) const override;
  void relaxTlsIeToLe(uint8_t *loc, RelType type, uint64_t val) const override;
};
} // namespace

static uint16_t lo(uint32_t v) { return v; }
static uint16_t ha(uint32_t v) { return (v + 0x8000) >> 16; }

static uint32_t readFromHalf16(const uint8_t *loc) {
  return read32(config->isLE ? loc : loc - 2);
}

static void writeFromHalf16(uint8_t *loc, uint32_t insn) {
  write32(config->isLE ? loc : loc - 2, insn);
}

void elf::writePPC32GlinkSection(uint8_t *buf, size_t numEntries) {
  // On PPC Secure PLT ABI, bl foo@plt jumps to a call stub, which loads an
  // absolute address from a specific .plt slot (usually called .got.plt on
  // other targets) and jumps there.
  //
  // a) With immediate binding (BIND_NOW), the .plt entry is resolved at load
  // time. The .glink section is not used.
  // b) With lazy binding, the .plt entry points to a `b PLTresolve`
  // instruction in .glink, filled in by PPC::writeGotPlt().

  // Write N `b PLTresolve` first.
  for (size_t i = 0; i != numEntries; ++i)
    write32(buf + 4 * i, 0x48000000 | 4 * (numEntries - i));
  buf += 4 * numEntries;

  // Then write PLTresolve(), which has two forms: PIC and non-PIC. PLTresolve()
  // computes the PLT index (by computing the distance from the landing b to
  // itself) and calls _dl_runtime_resolve() (in glibc).
  uint32_t got = in.got->getVA();
  uint32_t glink = in.plt->getVA(); // VA of .glink
  const uint8_t *end = buf + 64;
  if (config->isPic) {
    uint32_t afterBcl = in.plt->getSize() - target->pltHeaderSize + 12;
    uint32_t gotBcl = got + 4 - (glink + afterBcl);
    write32(buf + 0, 0x3d6b0000 | ha(afterBcl));  // addis r11,r11,1f-glink@ha
    write32(buf + 4, 0x7c0802a6);                 // mflr r0
    write32(buf + 8, 0x429f0005);                 // bcl 20,30,.+4
    write32(buf + 12, 0x396b0000 | lo(afterBcl)); // 1: addi r11,r11,1b-.glink@l
    write32(buf + 16, 0x7d8802a6);                // mflr r12
    write32(buf + 20, 0x7c0803a6);                // mtlr r0
    write32(buf + 24, 0x7d6c5850);                // sub r11,r11,r12
    write32(buf + 28, 0x3d8c0000 | ha(gotBcl));   // addis 12,12,GOT+4-1b@ha
    if (ha(gotBcl) == ha(gotBcl + 4)) {
      write32(buf + 32, 0x800c0000 | lo(gotBcl)); // lwz r0,r12,GOT+4-1b@l(r12)
      write32(buf + 36,
              0x818c0000 | lo(gotBcl + 4));       // lwz r12,r12,GOT+8-1b@l(r12)
    } else {
      write32(buf + 32, 0x840c0000 | lo(gotBcl)); // lwzu r0,r12,GOT+4-1b@l(r12)
      write32(buf + 36, 0x818c0000 | 4);          // lwz r12,r12,4(r12)
    }
    write32(buf + 40, 0x7c0903a6);                // mtctr 0
    write32(buf + 44, 0x7c0b5a14);                // add r0,11,11
    write32(buf + 48, 0x7d605a14);                // add r11,0,11
    write32(buf + 52, 0x4e800420);                // bctr
    buf += 56;
  } else {
    write32(buf + 0, 0x3d800000 | ha(got + 4));   // lis     r12,GOT+4@ha
    write32(buf + 4, 0x3d6b0000 | ha(-glink));    // addis   r11,r11,-Glink@ha
    if (ha(got + 4) == ha(got + 8))
      write32(buf + 8, 0x800c0000 | lo(got + 4)); // lwz r0,GOT+4@l(r12)
    else
      write32(buf + 8, 0x840c0000 | lo(got + 4)); // lwzu r0,GOT+4@l(r12)
    write32(buf + 12, 0x396b0000 | lo(-glink));   // addi    r11,r11,-Glink@l
    write32(buf + 16, 0x7c0903a6);                // mtctr   r0
    write32(buf + 20, 0x7c0b5a14);                // add     r0,r11,r11
    if (ha(got + 4) == ha(got + 8))
      write32(buf + 24, 0x818c0000 | lo(got + 8)); // lwz r12,GOT+8@ha(r12)
    else
      write32(buf + 24, 0x818c0000 | 4);          // lwz r12,4(r12)
    write32(buf + 28, 0x7d605a14);                // add     r11,r0,r11
    write32(buf + 32, 0x4e800420);                // bctr
    buf += 36;
  }

  // Pad with nop. They should not be executed.
  for (; buf < end; buf += 4)
    write32(buf, 0x60000000);
}

PPC::PPC() {
  gotRel = R_PPC_GLOB_DAT;
  noneRel = R_PPC_NONE;
  pltRel = R_PPC_JMP_SLOT;
  relativeRel = R_PPC_RELATIVE;
  iRelativeRel = R_PPC_IRELATIVE;
  symbolicRel = R_PPC_ADDR32;
  gotBaseSymInGotPlt = false;
  gotHeaderEntriesNum = 3;
  gotPltHeaderEntriesNum = 0;
  pltHeaderSize = 64; // size of PLTresolve in .glink
  pltEntrySize = 4;

  needsThunks = true;

  tlsModuleIndexRel = R_PPC_DTPMOD32;
  tlsOffsetRel = R_PPC_DTPREL32;
  tlsGotRel = R_PPC_TPREL32;

  defaultMaxPageSize = 65536;
  defaultImageBase = 0x10000000;

  write32(trapInstr.data(), 0x7fe00008);
}

void PPC::writeGotHeader(uint8_t *buf) const {
  // _GLOBAL_OFFSET_TABLE_[0] = _DYNAMIC
  // glibc stores _dl_runtime_resolve in _GLOBAL_OFFSET_TABLE_[1],
  // link_map in _GLOBAL_OFFSET_TABLE_[2].
  write32(buf, mainPart->dynamic->getVA());
}

void PPC::writeGotPlt(uint8_t *buf, const Symbol &s) const {
  // Address of the symbol resolver stub in .glink .
  write32(buf, in.plt->getVA() + 4 * s.pltIndex);
}

bool PPC::needsThunk(RelExpr expr, RelType type, const InputFile *file,
                     uint64_t branchAddr, const Symbol &s) const {
  if (type != R_PPC_REL24 && type != R_PPC_PLTREL24)
    return false;
  if (s.isInPlt())
    return true;
  if (s.isUndefWeak())
    return false;
  return !(expr == R_PC && PPC::inBranchRange(type, branchAddr, s.getVA()));
}

uint32_t PPC::getThunkSectionSpacing() const { return 0x2000000; }

bool PPC::inBranchRange(RelType type, uint64_t src, uint64_t dst) const {
  uint64_t offset = dst - src;
  if (type == R_PPC_REL24 || type == R_PPC_PLTREL24)
    return isInt<26>(offset);
  llvm_unreachable("unsupported relocation type used in branch");
}

RelExpr PPC::getRelExpr(RelType type, const Symbol &s,
                        const uint8_t *loc) const {
  switch (type) {
  case R_PPC_NONE:
    return R_NONE;
  case R_PPC_ADDR16_HA:
  case R_PPC_ADDR16_HI:
  case R_PPC_ADDR16_LO:
  case R_PPC_ADDR32:
    return R_ABS;
  case R_PPC_DTPREL16:
  case R_PPC_DTPREL16_HA:
  case R_PPC_DTPREL16_HI:
  case R_PPC_DTPREL16_LO:
  case R_PPC_DTPREL32:
    return R_DTPREL;
  case R_PPC_REL14:
  case R_PPC_REL32:
  case R_PPC_LOCAL24PC:
  case R_PPC_REL16_LO:
  case R_PPC_REL16_HI:
  case R_PPC_REL16_HA:
    return R_PC;
  case R_PPC_GOT16:
    return R_GOT_OFF;
  case R_PPC_REL24:
    return R_PLT_PC;
  case R_PPC_PLTREL24:
    return R_PPC32_PLTREL;
  case R_PPC_GOT_TLSGD16:
    return R_TLSGD_GOT;
  case R_PPC_GOT_TLSLD16:
    return R_TLSLD_GOT;
  case R_PPC_GOT_TPREL16:
    return R_GOT_OFF;
  case R_PPC_TLS:
    return R_TLSIE_HINT;
  case R_PPC_TLSGD:
    return R_TLSDESC_CALL;
  case R_PPC_TLSLD:
    return R_TLSLD_HINT;
  case R_PPC_TPREL16:
  case R_PPC_TPREL16_HA:
  case R_PPC_TPREL16_LO:
  case R_PPC_TPREL16_HI:
    return R_TLS;
  default:
    error(getErrorLocation(loc) + "unknown relocation (" + Twine(type) +
          ") against symbol " + toString(s));
    return R_NONE;
  }
}

RelType PPC::getDynRel(RelType type) const {
  if (type == R_PPC_ADDR32)
    return type;
  return R_PPC_NONE;
}

static std::pair<RelType, uint64_t> fromDTPREL(RelType type, uint64_t val) {
  uint64_t dtpBiasedVal = val - 0x8000;
  switch (type) {
  case R_PPC_DTPREL16:
    return {R_PPC64_ADDR16, dtpBiasedVal};
  case R_PPC_DTPREL16_HA:
    return {R_PPC_ADDR16_HA, dtpBiasedVal};
  case R_PPC_DTPREL16_HI:
    return {R_PPC_ADDR16_HI, dtpBiasedVal};
  case R_PPC_DTPREL16_LO:
    return {R_PPC_ADDR16_LO, dtpBiasedVal};
  case R_PPC_DTPREL32:
    return {R_PPC_ADDR32, dtpBiasedVal};
  default:
    return {type, val};
  }
}

void PPC::relocateOne(uint8_t *loc, RelType type, uint64_t val) const {
  RelType newType;
  std::tie(newType, val) = fromDTPREL(type, val);
  switch (newType) {
  case R_PPC_ADDR16:
    checkIntUInt(loc, val, 16, type);
    write16(loc, val);
    break;
  case R_PPC_GOT16:
  case R_PPC_GOT_TLSGD16:
  case R_PPC_GOT_TLSLD16:
  case R_PPC_GOT_TPREL16:
  case R_PPC_TPREL16:
    checkInt(loc, val, 16, type);
    write16(loc, val);
    break;
  case R_PPC_ADDR16_HA:
  case R_PPC_DTPREL16_HA:
  case R_PPC_GOT_TLSGD16_HA:
  case R_PPC_GOT_TLSLD16_HA:
  case R_PPC_GOT_TPREL16_HA:
  case R_PPC_REL16_HA:
  case R_PPC_TPREL16_HA:
    write16(loc, ha(val));
    break;
  case R_PPC_ADDR16_HI:
  case R_PPC_DTPREL16_HI:
  case R_PPC_GOT_TLSGD16_HI:
  case R_PPC_GOT_TLSLD16_HI:
  case R_PPC_GOT_TPREL16_HI:
  case R_PPC_REL16_HI:
  case R_PPC_TPREL16_HI:
    write16(loc, val >> 16);
    break;
  case R_PPC_ADDR16_LO:
  case R_PPC_DTPREL16_LO:
  case R_PPC_GOT_TLSGD16_LO:
  case R_PPC_GOT_TLSLD16_LO:
  case R_PPC_GOT_TPREL16_LO:
  case R_PPC_REL16_LO:
  case R_PPC_TPREL16_LO:
    write16(loc, val);
    break;
  case R_PPC_ADDR32:
  case R_PPC_REL32:
    write32(loc, val);
    break;
  case R_PPC_REL14: {
    uint32_t mask = 0x0000FFFC;
    checkInt(loc, val, 16, type);
    checkAlignment(loc, val, 4, type);
    write32(loc, (read32(loc) & ~mask) | (val & mask));
    break;
  }
  case R_PPC_REL24:
  case R_PPC_LOCAL24PC:
  case R_PPC_PLTREL24: {
    uint32_t mask = 0x03FFFFFC;
    checkInt(loc, val, 26, type);
    checkAlignment(loc, val, 4, type);
    write32(loc, (read32(loc) & ~mask) | (val & mask));
    break;
  }
  default:
    llvm_unreachable("unknown relocation");
  }
}

RelExpr PPC::adjustRelaxExpr(RelType type, const uint8_t *data,
                             RelExpr expr) const {
  if (expr == R_RELAX_TLS_GD_TO_IE)
    return R_RELAX_TLS_GD_TO_IE_GOT_OFF;
  if (expr == R_RELAX_TLS_LD_TO_LE)
    return R_RELAX_TLS_LD_TO_LE_ABS;
  return expr;
}

int PPC::getTlsGdRelaxSkip(RelType type) const {
  // A __tls_get_addr call instruction is marked with 2 relocations:
  //
  //   R_PPC_TLSGD / R_PPC_TLSLD: marker relocation
  //   R_PPC_REL24: __tls_get_addr
  //
  // After the relaxation we no longer call __tls_get_addr and should skip both
  // relocations to not create a false dependence on __tls_get_addr being
  // defined.
  if (type == R_PPC_TLSGD || type == R_PPC_TLSLD)
    return 2;
  return 1;
}

void PPC::relaxTlsGdToIe(uint8_t *loc, RelType type, uint64_t val) const {
  switch (type) {
  case R_PPC_GOT_TLSGD16: {
    // addi rT, rA, x@got@tlsgd --> lwz rT, x@got@tprel(rA)
    uint32_t insn = readFromHalf16(loc);
    writeFromHalf16(loc, 0x80000000 | (insn & 0x03ff0000));
    relocateOne(loc, R_PPC_GOT_TPREL16, val);
    break;
  }
  case R_PPC_TLSGD:
    // bl __tls_get_addr(x@tldgd) --> add r3, r3, r2
    write32(loc, 0x7c631214);
    break;
  default:
    llvm_unreachable("unsupported relocation for TLS GD to IE relaxation");
  }
}

void PPC::relaxTlsGdToLe(uint8_t *loc, RelType type, uint64_t val) const {
  switch (type) {
  case R_PPC_GOT_TLSGD16:
    // addi r3, r31, x@got@tlsgd --> addis r3, r2, x@tprel@ha
    writeFromHalf16(loc, 0x3c620000 | ha(val));
    break;
  case R_PPC_TLSGD:
    // bl __tls_get_addr(x@tldgd) --> add r3, r3, x@tprel@l
    write32(loc, 0x38630000 | lo(val));
    break;
  default:
    llvm_unreachable("unsupported relocation for TLS GD to LE relaxation");
  }
}

void PPC::relaxTlsLdToLe(uint8_t *loc, RelType type, uint64_t val) const {
  switch (type) {
  case R_PPC_GOT_TLSLD16:
    // addi r3, rA, x@got@tlsgd --> addis r3, r2, 0
    writeFromHalf16(loc, 0x3c620000);
    break;
  case R_PPC_TLSLD:
    // r3+x@dtprel computes r3+x-0x8000, while we want it to compute r3+x@tprel
    // = r3+x-0x7000, so add 4096 to r3.
    // bl __tls_get_addr(x@tlsld) --> addi r3, r3, 4096
    write32(loc, 0x38631000);
    break;
  case R_PPC_DTPREL16:
  case R_PPC_DTPREL16_HA:
  case R_PPC_DTPREL16_HI:
  case R_PPC_DTPREL16_LO:
    relocateOne(loc, type, val);
    break;
  default:
    llvm_unreachable("unsupported relocation for TLS LD to LE relaxation");
  }
}

void PPC::relaxTlsIeToLe(uint8_t *loc, RelType type, uint64_t val) const {
  switch (type) {
  case R_PPC_GOT_TPREL16: {
    // lwz rT, x@got@tprel(rA) --> addis rT, r2, x@tprel@ha
    uint32_t rt = readFromHalf16(loc) & 0x03e00000;
    writeFromHalf16(loc, 0x3c020000 | rt | ha(val));
    break;
  }
  case R_PPC_TLS: {
    uint32_t insn = read32(loc);
    if (insn >> 26 != 31)
      error("unrecognized instruction for IE to LE R_PPC_TLS");
    // addi rT, rT, x@tls --> addi rT, rT, x@tprel@l
    uint32_t dFormOp = getPPCDFormOp((read32(loc) & 0x000007fe) >> 1);
    if (dFormOp == 0)
      error("unrecognized instruction for IE to LE R_PPC_TLS");
    write32(loc, (dFormOp << 26) | (insn & 0x03ff0000) | lo(val));
    break;
  }
  default:
    llvm_unreachable("unsupported relocation for TLS IE to LE relaxation");
  }
}

TargetInfo *elf::getPPCTargetInfo() {
  static PPC target;
  return &target;
}
