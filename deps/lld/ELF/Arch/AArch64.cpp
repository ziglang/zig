//===- AArch64.cpp --------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "Symbols.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "Thunks.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/Object/ELF.h"
#include "llvm/Support/Endian.h"

using namespace llvm;
using namespace llvm::support::endian;
using namespace llvm::ELF;
using namespace lld;
using namespace lld::elf;

// Page(Expr) is the page address of the expression Expr, defined
// as (Expr & ~0xFFF). (This applies even if the machine page size
// supported by the platform has a different value.)
uint64_t elf::getAArch64Page(uint64_t expr) {
  return expr & ~static_cast<uint64_t>(0xFFF);
}

namespace {
class AArch64 : public TargetInfo {
public:
  AArch64();
  RelExpr getRelExpr(RelType type, const Symbol &s,
                     const uint8_t *loc) const override;
  RelType getDynRel(RelType type) const override;
  void writeGotPlt(uint8_t *buf, const Symbol &s) const override;
  void writePltHeader(uint8_t *buf) const override;
  void writePlt(uint8_t *buf, uint64_t gotPltEntryAddr, uint64_t pltEntryAddr,
                int32_t index, unsigned relOff) const override;
  bool needsThunk(RelExpr expr, RelType type, const InputFile *file,
                  uint64_t branchAddr, const Symbol &s) const override;
  uint32_t getThunkSectionSpacing() const override;
  bool inBranchRange(RelType type, uint64_t src, uint64_t dst) const override;
  bool usesOnlyLowPageBits(RelType type) const override;
  void relocateOne(uint8_t *loc, RelType type, uint64_t val) const override;
  RelExpr adjustRelaxExpr(RelType type, const uint8_t *data,
                          RelExpr expr) const override;
  void relaxTlsGdToLe(uint8_t *loc, RelType type, uint64_t val) const override;
  void relaxTlsGdToIe(uint8_t *loc, RelType type, uint64_t val) const override;
  void relaxTlsIeToLe(uint8_t *loc, RelType type, uint64_t val) const override;
};
} // namespace

AArch64::AArch64() {
  copyRel = R_AARCH64_COPY;
  relativeRel = R_AARCH64_RELATIVE;
  iRelativeRel = R_AARCH64_IRELATIVE;
  gotRel = R_AARCH64_GLOB_DAT;
  noneRel = R_AARCH64_NONE;
  pltRel = R_AARCH64_JUMP_SLOT;
  symbolicRel = R_AARCH64_ABS64;
  tlsDescRel = R_AARCH64_TLSDESC;
  tlsGotRel = R_AARCH64_TLS_TPREL64;
  pltEntrySize = 16;
  pltHeaderSize = 32;
  defaultMaxPageSize = 65536;

  // Align to the 2 MiB page size (known as a superpage or huge page).
  // FreeBSD automatically promotes 2 MiB-aligned allocations.
  defaultImageBase = 0x200000;

  needsThunks = true;
}

RelExpr AArch64::getRelExpr(RelType type, const Symbol &s,
                            const uint8_t *loc) const {
  switch (type) {
  case R_AARCH64_TLSDESC_ADR_PAGE21:
    return R_AARCH64_TLSDESC_PAGE;
  case R_AARCH64_TLSDESC_LD64_LO12:
  case R_AARCH64_TLSDESC_ADD_LO12:
    return R_TLSDESC;
  case R_AARCH64_TLSDESC_CALL:
    return R_TLSDESC_CALL;
  case R_AARCH64_TLSLE_ADD_TPREL_HI12:
  case R_AARCH64_TLSLE_ADD_TPREL_LO12_NC:
  case R_AARCH64_TLSLE_LDST8_TPREL_LO12_NC:
  case R_AARCH64_TLSLE_LDST16_TPREL_LO12_NC:
  case R_AARCH64_TLSLE_LDST32_TPREL_LO12_NC:
  case R_AARCH64_TLSLE_LDST64_TPREL_LO12_NC:
  case R_AARCH64_TLSLE_LDST128_TPREL_LO12_NC:
    return R_TLS;
  case R_AARCH64_CALL26:
  case R_AARCH64_CONDBR19:
  case R_AARCH64_JUMP26:
  case R_AARCH64_TSTBR14:
    return R_PLT_PC;
  case R_AARCH64_PREL16:
  case R_AARCH64_PREL32:
  case R_AARCH64_PREL64:
  case R_AARCH64_ADR_PREL_LO21:
  case R_AARCH64_LD_PREL_LO19:
    return R_PC;
  case R_AARCH64_ADR_PREL_PG_HI21:
  case R_AARCH64_ADR_PREL_PG_HI21_NC:
    return R_AARCH64_PAGE_PC;
  case R_AARCH64_LD64_GOT_LO12_NC:
  case R_AARCH64_TLSIE_LD64_GOTTPREL_LO12_NC:
    return R_GOT;
  case R_AARCH64_ADR_GOT_PAGE:
  case R_AARCH64_TLSIE_ADR_GOTTPREL_PAGE21:
    return R_AARCH64_GOT_PAGE_PC;
  case R_AARCH64_NONE:
    return R_NONE;
  default:
    return R_ABS;
  }
}

RelExpr AArch64::adjustRelaxExpr(RelType type, const uint8_t *data,
                                 RelExpr expr) const {
  if (expr == R_RELAX_TLS_GD_TO_IE) {
    if (type == R_AARCH64_TLSDESC_ADR_PAGE21)
      return R_AARCH64_RELAX_TLS_GD_TO_IE_PAGE_PC;
    return R_RELAX_TLS_GD_TO_IE_ABS;
  }
  return expr;
}

bool AArch64::usesOnlyLowPageBits(RelType type) const {
  switch (type) {
  default:
    return false;
  case R_AARCH64_ADD_ABS_LO12_NC:
  case R_AARCH64_LD64_GOT_LO12_NC:
  case R_AARCH64_LDST128_ABS_LO12_NC:
  case R_AARCH64_LDST16_ABS_LO12_NC:
  case R_AARCH64_LDST32_ABS_LO12_NC:
  case R_AARCH64_LDST64_ABS_LO12_NC:
  case R_AARCH64_LDST8_ABS_LO12_NC:
  case R_AARCH64_TLSDESC_ADD_LO12:
  case R_AARCH64_TLSDESC_LD64_LO12:
  case R_AARCH64_TLSIE_LD64_GOTTPREL_LO12_NC:
    return true;
  }
}

RelType AArch64::getDynRel(RelType type) const {
  if (type == R_AARCH64_ABS64)
    return type;
  return R_AARCH64_NONE;
}

void AArch64::writeGotPlt(uint8_t *buf, const Symbol &) const {
  write64le(buf, in.plt->getVA());
}

void AArch64::writePltHeader(uint8_t *buf) const {
  const uint8_t pltData[] = {
      0xf0, 0x7b, 0xbf, 0xa9, // stp    x16, x30, [sp,#-16]!
      0x10, 0x00, 0x00, 0x90, // adrp   x16, Page(&(.plt.got[2]))
      0x11, 0x02, 0x40, 0xf9, // ldr    x17, [x16, Offset(&(.plt.got[2]))]
      0x10, 0x02, 0x00, 0x91, // add    x16, x16, Offset(&(.plt.got[2]))
      0x20, 0x02, 0x1f, 0xd6, // br     x17
      0x1f, 0x20, 0x03, 0xd5, // nop
      0x1f, 0x20, 0x03, 0xd5, // nop
      0x1f, 0x20, 0x03, 0xd5  // nop
  };
  memcpy(buf, pltData, sizeof(pltData));

  uint64_t got = in.gotPlt->getVA();
  uint64_t plt = in.plt->getVA();
  relocateOne(buf + 4, R_AARCH64_ADR_PREL_PG_HI21,
              getAArch64Page(got + 16) - getAArch64Page(plt + 4));
  relocateOne(buf + 8, R_AARCH64_LDST64_ABS_LO12_NC, got + 16);
  relocateOne(buf + 12, R_AARCH64_ADD_ABS_LO12_NC, got + 16);
}

void AArch64::writePlt(uint8_t *buf, uint64_t gotPltEntryAddr,
                       uint64_t pltEntryAddr, int32_t index,
                       unsigned relOff) const {
  const uint8_t inst[] = {
      0x10, 0x00, 0x00, 0x90, // adrp x16, Page(&(.plt.got[n]))
      0x11, 0x02, 0x40, 0xf9, // ldr  x17, [x16, Offset(&(.plt.got[n]))]
      0x10, 0x02, 0x00, 0x91, // add  x16, x16, Offset(&(.plt.got[n]))
      0x20, 0x02, 0x1f, 0xd6  // br   x17
  };
  memcpy(buf, inst, sizeof(inst));

  relocateOne(buf, R_AARCH64_ADR_PREL_PG_HI21,
              getAArch64Page(gotPltEntryAddr) - getAArch64Page(pltEntryAddr));
  relocateOne(buf + 4, R_AARCH64_LDST64_ABS_LO12_NC, gotPltEntryAddr);
  relocateOne(buf + 8, R_AARCH64_ADD_ABS_LO12_NC, gotPltEntryAddr);
}

bool AArch64::needsThunk(RelExpr expr, RelType type, const InputFile *file,
                         uint64_t branchAddr, const Symbol &s) const {
  // ELF for the ARM 64-bit architecture, section Call and Jump relocations
  // only permits range extension thunks for R_AARCH64_CALL26 and
  // R_AARCH64_JUMP26 relocation types.
  if (type != R_AARCH64_CALL26 && type != R_AARCH64_JUMP26)
    return false;
  uint64_t dst = (expr == R_PLT_PC) ? s.getPltVA() : s.getVA();
  return !inBranchRange(type, branchAddr, dst);
}

uint32_t AArch64::getThunkSectionSpacing() const {
  // See comment in Arch/ARM.cpp for a more detailed explanation of
  // getThunkSectionSpacing(). For AArch64 the only branches we are permitted to
  // Thunk have a range of +/- 128 MiB
  return (128 * 1024 * 1024) - 0x30000;
}

bool AArch64::inBranchRange(RelType type, uint64_t src, uint64_t dst) const {
  if (type != R_AARCH64_CALL26 && type != R_AARCH64_JUMP26)
    return true;
  // The AArch64 call and unconditional branch instructions have a range of
  // +/- 128 MiB.
  uint64_t range = 128 * 1024 * 1024;
  if (dst > src) {
    // Immediate of branch is signed.
    range -= 4;
    return dst - src <= range;
  }
  return src - dst <= range;
}

static void write32AArch64Addr(uint8_t *l, uint64_t imm) {
  uint32_t immLo = (imm & 0x3) << 29;
  uint32_t immHi = (imm & 0x1FFFFC) << 3;
  uint64_t mask = (0x3 << 29) | (0x1FFFFC << 3);
  write32le(l, (read32le(l) & ~mask) | immLo | immHi);
}

// Return the bits [Start, End] from Val shifted Start bits.
// For instance, getBits(0xF0, 4, 8) returns 0xF.
static uint64_t getBits(uint64_t val, int start, int end) {
  uint64_t mask = ((uint64_t)1 << (end + 1 - start)) - 1;
  return (val >> start) & mask;
}

static void or32le(uint8_t *p, int32_t v) { write32le(p, read32le(p) | v); }

// Update the immediate field in a AARCH64 ldr, str, and add instruction.
static void or32AArch64Imm(uint8_t *l, uint64_t imm) {
  or32le(l, (imm & 0xFFF) << 10);
}

void AArch64::relocateOne(uint8_t *loc, RelType type, uint64_t val) const {
  switch (type) {
  case R_AARCH64_ABS16:
  case R_AARCH64_PREL16:
    checkIntUInt(loc, val, 16, type);
    write16le(loc, val);
    break;
  case R_AARCH64_ABS32:
  case R_AARCH64_PREL32:
    checkIntUInt(loc, val, 32, type);
    write32le(loc, val);
    break;
  case R_AARCH64_ABS64:
  case R_AARCH64_PREL64:
    write64le(loc, val);
    break;
  case R_AARCH64_ADD_ABS_LO12_NC:
    or32AArch64Imm(loc, val);
    break;
  case R_AARCH64_ADR_GOT_PAGE:
  case R_AARCH64_ADR_PREL_PG_HI21:
  case R_AARCH64_TLSIE_ADR_GOTTPREL_PAGE21:
  case R_AARCH64_TLSDESC_ADR_PAGE21:
    checkInt(loc, val, 33, type);
    LLVM_FALLTHROUGH;
  case R_AARCH64_ADR_PREL_PG_HI21_NC:
    write32AArch64Addr(loc, val >> 12);
    break;
  case R_AARCH64_ADR_PREL_LO21:
    checkInt(loc, val, 21, type);
    write32AArch64Addr(loc, val);
    break;
  case R_AARCH64_JUMP26:
    // Normally we would just write the bits of the immediate field, however
    // when patching instructions for the cpu errata fix -fix-cortex-a53-843419
    // we want to replace a non-branch instruction with a branch immediate
    // instruction. By writing all the bits of the instruction including the
    // opcode and the immediate (0 001 | 01 imm26) we can do this
    // transformation by placing a R_AARCH64_JUMP26 relocation at the offset of
    // the instruction we want to patch.
    write32le(loc, 0x14000000);
    LLVM_FALLTHROUGH;
  case R_AARCH64_CALL26:
    checkInt(loc, val, 28, type);
    or32le(loc, (val & 0x0FFFFFFC) >> 2);
    break;
  case R_AARCH64_CONDBR19:
  case R_AARCH64_LD_PREL_LO19:
    checkAlignment(loc, val, 4, type);
    checkInt(loc, val, 21, type);
    or32le(loc, (val & 0x1FFFFC) << 3);
    break;
  case R_AARCH64_LDST8_ABS_LO12_NC:
  case R_AARCH64_TLSLE_LDST8_TPREL_LO12_NC:
    or32AArch64Imm(loc, getBits(val, 0, 11));
    break;
  case R_AARCH64_LDST16_ABS_LO12_NC:
  case R_AARCH64_TLSLE_LDST16_TPREL_LO12_NC:
    checkAlignment(loc, val, 2, type);
    or32AArch64Imm(loc, getBits(val, 1, 11));
    break;
  case R_AARCH64_LDST32_ABS_LO12_NC:
  case R_AARCH64_TLSLE_LDST32_TPREL_LO12_NC:
    checkAlignment(loc, val, 4, type);
    or32AArch64Imm(loc, getBits(val, 2, 11));
    break;
  case R_AARCH64_LDST64_ABS_LO12_NC:
  case R_AARCH64_LD64_GOT_LO12_NC:
  case R_AARCH64_TLSIE_LD64_GOTTPREL_LO12_NC:
  case R_AARCH64_TLSLE_LDST64_TPREL_LO12_NC:
  case R_AARCH64_TLSDESC_LD64_LO12:
    checkAlignment(loc, val, 8, type);
    or32AArch64Imm(loc, getBits(val, 3, 11));
    break;
  case R_AARCH64_LDST128_ABS_LO12_NC:
  case R_AARCH64_TLSLE_LDST128_TPREL_LO12_NC:
    checkAlignment(loc, val, 16, type);
    or32AArch64Imm(loc, getBits(val, 4, 11));
    break;
  case R_AARCH64_MOVW_UABS_G0_NC:
    or32le(loc, (val & 0xFFFF) << 5);
    break;
  case R_AARCH64_MOVW_UABS_G1_NC:
    or32le(loc, (val & 0xFFFF0000) >> 11);
    break;
  case R_AARCH64_MOVW_UABS_G2_NC:
    or32le(loc, (val & 0xFFFF00000000) >> 27);
    break;
  case R_AARCH64_MOVW_UABS_G3:
    or32le(loc, (val & 0xFFFF000000000000) >> 43);
    break;
  case R_AARCH64_TSTBR14:
    checkInt(loc, val, 16, type);
    or32le(loc, (val & 0xFFFC) << 3);
    break;
  case R_AARCH64_TLSLE_ADD_TPREL_HI12:
    checkUInt(loc, val, 24, type);
    or32AArch64Imm(loc, val >> 12);
    break;
  case R_AARCH64_TLSLE_ADD_TPREL_LO12_NC:
  case R_AARCH64_TLSDESC_ADD_LO12:
    or32AArch64Imm(loc, val);
    break;
  default:
    error(getErrorLocation(loc) + "unrecognized relocation " + toString(type));
  }
}

void AArch64::relaxTlsGdToLe(uint8_t *loc, RelType type, uint64_t val) const {
  // TLSDESC Global-Dynamic relocation are in the form:
  //   adrp    x0, :tlsdesc:v             [R_AARCH64_TLSDESC_ADR_PAGE21]
  //   ldr     x1, [x0, #:tlsdesc_lo12:v  [R_AARCH64_TLSDESC_LD64_LO12]
  //   add     x0, x0, :tlsdesc_los:v     [R_AARCH64_TLSDESC_ADD_LO12]
  //   .tlsdesccall                       [R_AARCH64_TLSDESC_CALL]
  //   blr     x1
  // And it can optimized to:
  //   movz    x0, #0x0, lsl #16
  //   movk    x0, #0x10
  //   nop
  //   nop
  checkUInt(loc, val, 32, type);

  switch (type) {
  case R_AARCH64_TLSDESC_ADD_LO12:
  case R_AARCH64_TLSDESC_CALL:
    write32le(loc, 0xd503201f); // nop
    return;
  case R_AARCH64_TLSDESC_ADR_PAGE21:
    write32le(loc, 0xd2a00000 | (((val >> 16) & 0xffff) << 5)); // movz
    return;
  case R_AARCH64_TLSDESC_LD64_LO12:
    write32le(loc, 0xf2800000 | ((val & 0xffff) << 5)); // movk
    return;
  default:
    llvm_unreachable("unsupported relocation for TLS GD to LE relaxation");
  }
}

void AArch64::relaxTlsGdToIe(uint8_t *loc, RelType type, uint64_t val) const {
  // TLSDESC Global-Dynamic relocation are in the form:
  //   adrp    x0, :tlsdesc:v             [R_AARCH64_TLSDESC_ADR_PAGE21]
  //   ldr     x1, [x0, #:tlsdesc_lo12:v  [R_AARCH64_TLSDESC_LD64_LO12]
  //   add     x0, x0, :tlsdesc_los:v     [R_AARCH64_TLSDESC_ADD_LO12]
  //   .tlsdesccall                       [R_AARCH64_TLSDESC_CALL]
  //   blr     x1
  // And it can optimized to:
  //   adrp    x0, :gottprel:v
  //   ldr     x0, [x0, :gottprel_lo12:v]
  //   nop
  //   nop

  switch (type) {
  case R_AARCH64_TLSDESC_ADD_LO12:
  case R_AARCH64_TLSDESC_CALL:
    write32le(loc, 0xd503201f); // nop
    break;
  case R_AARCH64_TLSDESC_ADR_PAGE21:
    write32le(loc, 0x90000000); // adrp
    relocateOne(loc, R_AARCH64_TLSIE_ADR_GOTTPREL_PAGE21, val);
    break;
  case R_AARCH64_TLSDESC_LD64_LO12:
    write32le(loc, 0xf9400000); // ldr
    relocateOne(loc, R_AARCH64_TLSIE_LD64_GOTTPREL_LO12_NC, val);
    break;
  default:
    llvm_unreachable("unsupported relocation for TLS GD to LE relaxation");
  }
}

void AArch64::relaxTlsIeToLe(uint8_t *loc, RelType type, uint64_t val) const {
  checkUInt(loc, val, 32, type);

  if (type == R_AARCH64_TLSIE_ADR_GOTTPREL_PAGE21) {
    // Generate MOVZ.
    uint32_t regNo = read32le(loc) & 0x1f;
    write32le(loc, (0xd2a00000 | regNo) | (((val >> 16) & 0xffff) << 5));
    return;
  }
  if (type == R_AARCH64_TLSIE_LD64_GOTTPREL_LO12_NC) {
    // Generate MOVK.
    uint32_t regNo = read32le(loc) & 0x1f;
    write32le(loc, (0xf2800000 | regNo) | ((val & 0xffff) << 5));
    return;
  }
  llvm_unreachable("invalid relocation for TLS IE to LE relaxation");
}

// AArch64 may use security features in variant PLT sequences. These are:
// Pointer Authentication (PAC), introduced in armv8.3-a and Branch Target
// Indicator (BTI) introduced in armv8.5-a. The additional instructions used
// in the variant Plt sequences are encoded in the Hint space so they can be
// deployed on older architectures, which treat the instructions as a nop.
// PAC and BTI can be combined leading to the following combinations:
// writePltHeader
// writePltHeaderBti (no PAC Header needed)
// writePlt
// writePltBti (BTI only)
// writePltPac (PAC only)
// writePltBtiPac (BTI and PAC)
//
// When PAC is enabled the dynamic loader encrypts the address that it places
// in the .got.plt using the pacia1716 instruction which encrypts the value in
// x17 using the modifier in x16. The static linker places autia1716 before the
// indirect branch to x17 to authenticate the address in x17 with the modifier
// in x16. This makes it more difficult for an attacker to modify the value in
// the .got.plt.
//
// When BTI is enabled all indirect branches must land on a bti instruction.
// The static linker must place a bti instruction at the start of any PLT entry
// that may be the target of an indirect branch. As the PLT entries call the
// lazy resolver indirectly this must have a bti instruction at start. In
// general a bti instruction is not needed for a PLT entry as indirect calls
// are resolved to the function address and not the PLT entry for the function.
// There are a small number of cases where the PLT address can escape, such as
// taking the address of a function or ifunc via a non got-generating
// relocation, and a shared library refers to that symbol.
//
// We use the bti c variant of the instruction which permits indirect branches
// (br) via x16/x17 and indirect function calls (blr) via any register. The ABI
// guarantees that all indirect branches from code requiring BTI protection
// will go via x16/x17

namespace {
class AArch64BtiPac final : public AArch64 {
public:
  AArch64BtiPac();
  void writePltHeader(uint8_t *buf) const override;
  void writePlt(uint8_t *buf, uint64_t gotPltEntryAddr, uint64_t pltEntryAddr,
                int32_t index, unsigned relOff) const override;

private:
  bool btiHeader; // bti instruction needed in PLT Header
  bool btiEntry;  // bti instruction needed in PLT Entry
  bool pacEntry;  // autia1716 instruction needed in PLT Entry
};
} // namespace

AArch64BtiPac::AArch64BtiPac() {
  btiHeader = (config->andFeatures & GNU_PROPERTY_AARCH64_FEATURE_1_BTI);
  // A BTI (Branch Target Indicator) Plt Entry is only required if the
  // address of the PLT entry can be taken by the program, which permits an
  // indirect jump to the PLT entry. This can happen when the address
  // of the PLT entry for a function is canonicalised due to the address of
  // the function in an executable being taken by a shared library.
  // FIXME: There is a potential optimization to omit the BTI if we detect
  // that the address of the PLT entry isn't taken.
  btiEntry = btiHeader && !config->shared;
  pacEntry = (config->andFeatures & GNU_PROPERTY_AARCH64_FEATURE_1_PAC);

  if (btiEntry || pacEntry)
    pltEntrySize = 24;
}

void AArch64BtiPac::writePltHeader(uint8_t *buf) const {
  const uint8_t btiData[] = { 0x5f, 0x24, 0x03, 0xd5 }; // bti c
  const uint8_t pltData[] = {
      0xf0, 0x7b, 0xbf, 0xa9, // stp    x16, x30, [sp,#-16]!
      0x10, 0x00, 0x00, 0x90, // adrp   x16, Page(&(.plt.got[2]))
      0x11, 0x02, 0x40, 0xf9, // ldr    x17, [x16, Offset(&(.plt.got[2]))]
      0x10, 0x02, 0x00, 0x91, // add    x16, x16, Offset(&(.plt.got[2]))
      0x20, 0x02, 0x1f, 0xd6, // br     x17
      0x1f, 0x20, 0x03, 0xd5, // nop
      0x1f, 0x20, 0x03, 0xd5  // nop
  };
  const uint8_t nopData[] = { 0x1f, 0x20, 0x03, 0xd5 }; // nop

  uint64_t got = in.gotPlt->getVA();
  uint64_t plt = in.plt->getVA();

  if (btiHeader) {
    // PltHeader is called indirectly by plt[N]. Prefix pltData with a BTI C
    // instruction.
    memcpy(buf, btiData, sizeof(btiData));
    buf += sizeof(btiData);
    plt += sizeof(btiData);
  }
  memcpy(buf, pltData, sizeof(pltData));

  relocateOne(buf + 4, R_AARCH64_ADR_PREL_PG_HI21,
              getAArch64Page(got + 16) - getAArch64Page(plt + 8));
  relocateOne(buf + 8, R_AARCH64_LDST64_ABS_LO12_NC, got + 16);
  relocateOne(buf + 12, R_AARCH64_ADD_ABS_LO12_NC, got + 16);
  if (!btiHeader)
    // We didn't add the BTI c instruction so round out size with NOP.
    memcpy(buf + sizeof(pltData), nopData, sizeof(nopData));
}

void AArch64BtiPac::writePlt(uint8_t *buf, uint64_t gotPltEntryAddr,
                             uint64_t pltEntryAddr, int32_t index,
                             unsigned relOff) const {
  // The PLT entry is of the form:
  // [btiData] addrInst (pacBr | stdBr) [nopData]
  const uint8_t btiData[] = { 0x5f, 0x24, 0x03, 0xd5 }; // bti c
  const uint8_t addrInst[] = {
      0x10, 0x00, 0x00, 0x90,  // adrp x16, Page(&(.plt.got[n]))
      0x11, 0x02, 0x40, 0xf9,  // ldr  x17, [x16, Offset(&(.plt.got[n]))]
      0x10, 0x02, 0x00, 0x91   // add  x16, x16, Offset(&(.plt.got[n]))
  };
  const uint8_t pacBr[] = {
      0x9f, 0x21, 0x03, 0xd5,  // autia1716
      0x20, 0x02, 0x1f, 0xd6   // br   x17
  };
  const uint8_t stdBr[] = {
      0x20, 0x02, 0x1f, 0xd6,  // br   x17
      0x1f, 0x20, 0x03, 0xd5   // nop
  };
  const uint8_t nopData[] = { 0x1f, 0x20, 0x03, 0xd5 }; // nop

  if (btiEntry) {
    memcpy(buf, btiData, sizeof(btiData));
    buf += sizeof(btiData);
    pltEntryAddr += sizeof(btiData);
  }

  memcpy(buf, addrInst, sizeof(addrInst));
  relocateOne(buf, R_AARCH64_ADR_PREL_PG_HI21,
              getAArch64Page(gotPltEntryAddr) -
                  getAArch64Page(pltEntryAddr));
  relocateOne(buf + 4, R_AARCH64_LDST64_ABS_LO12_NC, gotPltEntryAddr);
  relocateOne(buf + 8, R_AARCH64_ADD_ABS_LO12_NC, gotPltEntryAddr);

  if (pacEntry)
    memcpy(buf + sizeof(addrInst), pacBr, sizeof(pacBr));
  else
    memcpy(buf + sizeof(addrInst), stdBr, sizeof(stdBr));
  if (!btiEntry)
    // We didn't add the BTI c instruction so round out size with NOP.
    memcpy(buf + sizeof(addrInst) + sizeof(stdBr), nopData, sizeof(nopData));
}

static TargetInfo *getTargetInfo() {
  if (config->andFeatures & (GNU_PROPERTY_AARCH64_FEATURE_1_BTI |
                             GNU_PROPERTY_AARCH64_FEATURE_1_PAC)) {
    static AArch64BtiPac t;
    return &t;
  }
  static AArch64 t;
  return &t;
}

TargetInfo *elf::getAArch64TargetInfo() { return getTargetInfo(); }
