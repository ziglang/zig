//===- AArch64.cpp --------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "Error.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "Thunks.h"
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
uint64_t elf::getAArch64Page(uint64_t Expr) {
  return Expr & ~static_cast<uint64_t>(0xFFF);
}

namespace {
class AArch64 final : public TargetInfo {
public:
  AArch64();
  RelExpr getRelExpr(uint32_t Type, const SymbolBody &S,
                     const uint8_t *Loc) const override;
  bool isPicRel(uint32_t Type) const override;
  void writeGotPlt(uint8_t *Buf, const SymbolBody &S) const override;
  void writePltHeader(uint8_t *Buf) const override;
  void writePlt(uint8_t *Buf, uint64_t GotPltEntryAddr, uint64_t PltEntryAddr,
                int32_t Index, unsigned RelOff) const override;
  bool usesOnlyLowPageBits(uint32_t Type) const override;
  void relocateOne(uint8_t *Loc, uint32_t Type, uint64_t Val) const override;
  RelExpr adjustRelaxExpr(uint32_t Type, const uint8_t *Data,
                          RelExpr Expr) const override;
  void relaxTlsGdToLe(uint8_t *Loc, uint32_t Type, uint64_t Val) const override;
  void relaxTlsGdToIe(uint8_t *Loc, uint32_t Type, uint64_t Val) const override;
  void relaxTlsIeToLe(uint8_t *Loc, uint32_t Type, uint64_t Val) const override;
};
} // namespace

AArch64::AArch64() {
  CopyRel = R_AARCH64_COPY;
  RelativeRel = R_AARCH64_RELATIVE;
  IRelativeRel = R_AARCH64_IRELATIVE;
  GotRel = R_AARCH64_GLOB_DAT;
  PltRel = R_AARCH64_JUMP_SLOT;
  TlsDescRel = R_AARCH64_TLSDESC;
  TlsGotRel = R_AARCH64_TLS_TPREL64;
  GotEntrySize = 8;
  GotPltEntrySize = 8;
  PltEntrySize = 16;
  PltHeaderSize = 32;
  DefaultMaxPageSize = 65536;

  // It doesn't seem to be documented anywhere, but tls on aarch64 uses variant
  // 1 of the tls structures and the tcb size is 16.
  TcbSize = 16;
}

RelExpr AArch64::getRelExpr(uint32_t Type, const SymbolBody &S,
                            const uint8_t *Loc) const {
  switch (Type) {
  default:
    return R_ABS;
  case R_AARCH64_TLSDESC_ADR_PAGE21:
    return R_TLSDESC_PAGE;
  case R_AARCH64_TLSDESC_LD64_LO12:
  case R_AARCH64_TLSDESC_ADD_LO12:
    return R_TLSDESC;
  case R_AARCH64_TLSDESC_CALL:
    return R_TLSDESC_CALL;
  case R_AARCH64_TLSLE_ADD_TPREL_HI12:
  case R_AARCH64_TLSLE_ADD_TPREL_LO12_NC:
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
    return R_PC;
  case R_AARCH64_ADR_PREL_PG_HI21:
    return R_PAGE_PC;
  case R_AARCH64_LD64_GOT_LO12_NC:
  case R_AARCH64_TLSIE_LD64_GOTTPREL_LO12_NC:
    return R_GOT;
  case R_AARCH64_ADR_GOT_PAGE:
  case R_AARCH64_TLSIE_ADR_GOTTPREL_PAGE21:
    return R_GOT_PAGE_PC;
  case R_AARCH64_NONE:
    return R_NONE;
  }
}

RelExpr AArch64::adjustRelaxExpr(uint32_t Type, const uint8_t *Data,
                                 RelExpr Expr) const {
  if (Expr == R_RELAX_TLS_GD_TO_IE) {
    if (Type == R_AARCH64_TLSDESC_ADR_PAGE21)
      return R_RELAX_TLS_GD_TO_IE_PAGE_PC;
    return R_RELAX_TLS_GD_TO_IE_ABS;
  }
  return Expr;
}

bool AArch64::usesOnlyLowPageBits(uint32_t Type) const {
  switch (Type) {
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

bool AArch64::isPicRel(uint32_t Type) const {
  return Type == R_AARCH64_ABS32 || Type == R_AARCH64_ABS64;
}

void AArch64::writeGotPlt(uint8_t *Buf, const SymbolBody &) const {
  write64le(Buf, InX::Plt->getVA());
}

void AArch64::writePltHeader(uint8_t *Buf) const {
  const uint8_t PltData[] = {
      0xf0, 0x7b, 0xbf, 0xa9, // stp    x16, x30, [sp,#-16]!
      0x10, 0x00, 0x00, 0x90, // adrp   x16, Page(&(.plt.got[2]))
      0x11, 0x02, 0x40, 0xf9, // ldr    x17, [x16, Offset(&(.plt.got[2]))]
      0x10, 0x02, 0x00, 0x91, // add    x16, x16, Offset(&(.plt.got[2]))
      0x20, 0x02, 0x1f, 0xd6, // br     x17
      0x1f, 0x20, 0x03, 0xd5, // nop
      0x1f, 0x20, 0x03, 0xd5, // nop
      0x1f, 0x20, 0x03, 0xd5  // nop
  };
  memcpy(Buf, PltData, sizeof(PltData));

  uint64_t Got = InX::GotPlt->getVA();
  uint64_t Plt = InX::Plt->getVA();
  relocateOne(Buf + 4, R_AARCH64_ADR_PREL_PG_HI21,
              getAArch64Page(Got + 16) - getAArch64Page(Plt + 4));
  relocateOne(Buf + 8, R_AARCH64_LDST64_ABS_LO12_NC, Got + 16);
  relocateOne(Buf + 12, R_AARCH64_ADD_ABS_LO12_NC, Got + 16);
}

void AArch64::writePlt(uint8_t *Buf, uint64_t GotPltEntryAddr,
                       uint64_t PltEntryAddr, int32_t Index,
                       unsigned RelOff) const {
  const uint8_t Inst[] = {
      0x10, 0x00, 0x00, 0x90, // adrp x16, Page(&(.plt.got[n]))
      0x11, 0x02, 0x40, 0xf9, // ldr  x17, [x16, Offset(&(.plt.got[n]))]
      0x10, 0x02, 0x00, 0x91, // add  x16, x16, Offset(&(.plt.got[n]))
      0x20, 0x02, 0x1f, 0xd6  // br   x17
  };
  memcpy(Buf, Inst, sizeof(Inst));

  relocateOne(Buf, R_AARCH64_ADR_PREL_PG_HI21,
              getAArch64Page(GotPltEntryAddr) - getAArch64Page(PltEntryAddr));
  relocateOne(Buf + 4, R_AARCH64_LDST64_ABS_LO12_NC, GotPltEntryAddr);
  relocateOne(Buf + 8, R_AARCH64_ADD_ABS_LO12_NC, GotPltEntryAddr);
}

static void write32AArch64Addr(uint8_t *L, uint64_t Imm) {
  uint32_t ImmLo = (Imm & 0x3) << 29;
  uint32_t ImmHi = (Imm & 0x1FFFFC) << 3;
  uint64_t Mask = (0x3 << 29) | (0x1FFFFC << 3);
  write32le(L, (read32le(L) & ~Mask) | ImmLo | ImmHi);
}

// Return the bits [Start, End] from Val shifted Start bits.
// For instance, getBits(0xF0, 4, 8) returns 0xF.
static uint64_t getBits(uint64_t Val, int Start, int End) {
  uint64_t Mask = ((uint64_t)1 << (End + 1 - Start)) - 1;
  return (Val >> Start) & Mask;
}

static void or32le(uint8_t *P, int32_t V) { write32le(P, read32le(P) | V); }

// Update the immediate field in a AARCH64 ldr, str, and add instruction.
static void or32AArch64Imm(uint8_t *L, uint64_t Imm) {
  or32le(L, (Imm & 0xFFF) << 10);
}

void AArch64::relocateOne(uint8_t *Loc, uint32_t Type, uint64_t Val) const {
  switch (Type) {
  case R_AARCH64_ABS16:
  case R_AARCH64_PREL16:
    checkIntUInt<16>(Loc, Val, Type);
    write16le(Loc, Val);
    break;
  case R_AARCH64_ABS32:
  case R_AARCH64_PREL32:
    checkIntUInt<32>(Loc, Val, Type);
    write32le(Loc, Val);
    break;
  case R_AARCH64_ABS64:
  case R_AARCH64_GLOB_DAT:
  case R_AARCH64_PREL64:
    write64le(Loc, Val);
    break;
  case R_AARCH64_ADD_ABS_LO12_NC:
    or32AArch64Imm(Loc, Val);
    break;
  case R_AARCH64_ADR_GOT_PAGE:
  case R_AARCH64_ADR_PREL_PG_HI21:
  case R_AARCH64_TLSIE_ADR_GOTTPREL_PAGE21:
  case R_AARCH64_TLSDESC_ADR_PAGE21:
    checkInt<33>(Loc, Val, Type);
    write32AArch64Addr(Loc, Val >> 12);
    break;
  case R_AARCH64_ADR_PREL_LO21:
    checkInt<21>(Loc, Val, Type);
    write32AArch64Addr(Loc, Val);
    break;
  case R_AARCH64_CALL26:
  case R_AARCH64_JUMP26:
    checkInt<28>(Loc, Val, Type);
    or32le(Loc, (Val & 0x0FFFFFFC) >> 2);
    break;
  case R_AARCH64_CONDBR19:
    checkInt<21>(Loc, Val, Type);
    or32le(Loc, (Val & 0x1FFFFC) << 3);
    break;
  case R_AARCH64_LD64_GOT_LO12_NC:
  case R_AARCH64_TLSIE_LD64_GOTTPREL_LO12_NC:
  case R_AARCH64_TLSDESC_LD64_LO12:
    checkAlignment<8>(Loc, Val, Type);
    or32le(Loc, (Val & 0xFF8) << 7);
    break;
  case R_AARCH64_LDST8_ABS_LO12_NC:
    or32AArch64Imm(Loc, getBits(Val, 0, 11));
    break;
  case R_AARCH64_LDST16_ABS_LO12_NC:
    or32AArch64Imm(Loc, getBits(Val, 1, 11));
    break;
  case R_AARCH64_LDST32_ABS_LO12_NC:
    or32AArch64Imm(Loc, getBits(Val, 2, 11));
    break;
  case R_AARCH64_LDST64_ABS_LO12_NC:
    or32AArch64Imm(Loc, getBits(Val, 3, 11));
    break;
  case R_AARCH64_LDST128_ABS_LO12_NC:
    or32AArch64Imm(Loc, getBits(Val, 4, 11));
    break;
  case R_AARCH64_MOVW_UABS_G0_NC:
    or32le(Loc, (Val & 0xFFFF) << 5);
    break;
  case R_AARCH64_MOVW_UABS_G1_NC:
    or32le(Loc, (Val & 0xFFFF0000) >> 11);
    break;
  case R_AARCH64_MOVW_UABS_G2_NC:
    or32le(Loc, (Val & 0xFFFF00000000) >> 27);
    break;
  case R_AARCH64_MOVW_UABS_G3:
    or32le(Loc, (Val & 0xFFFF000000000000) >> 43);
    break;
  case R_AARCH64_TSTBR14:
    checkInt<16>(Loc, Val, Type);
    or32le(Loc, (Val & 0xFFFC) << 3);
    break;
  case R_AARCH64_TLSLE_ADD_TPREL_HI12:
    checkInt<24>(Loc, Val, Type);
    or32AArch64Imm(Loc, Val >> 12);
    break;
  case R_AARCH64_TLSLE_ADD_TPREL_LO12_NC:
  case R_AARCH64_TLSDESC_ADD_LO12:
    or32AArch64Imm(Loc, Val);
    break;
  default:
    error(getErrorLocation(Loc) + "unrecognized reloc " + Twine(Type));
  }
}

void AArch64::relaxTlsGdToLe(uint8_t *Loc, uint32_t Type, uint64_t Val) const {
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
  checkUInt<32>(Loc, Val, Type);

  switch (Type) {
  case R_AARCH64_TLSDESC_ADD_LO12:
  case R_AARCH64_TLSDESC_CALL:
    write32le(Loc, 0xd503201f); // nop
    return;
  case R_AARCH64_TLSDESC_ADR_PAGE21:
    write32le(Loc, 0xd2a00000 | (((Val >> 16) & 0xffff) << 5)); // movz
    return;
  case R_AARCH64_TLSDESC_LD64_LO12:
    write32le(Loc, 0xf2800000 | ((Val & 0xffff) << 5)); // movk
    return;
  default:
    llvm_unreachable("unsupported relocation for TLS GD to LE relaxation");
  }
}

void AArch64::relaxTlsGdToIe(uint8_t *Loc, uint32_t Type, uint64_t Val) const {
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

  switch (Type) {
  case R_AARCH64_TLSDESC_ADD_LO12:
  case R_AARCH64_TLSDESC_CALL:
    write32le(Loc, 0xd503201f); // nop
    break;
  case R_AARCH64_TLSDESC_ADR_PAGE21:
    write32le(Loc, 0x90000000); // adrp
    relocateOne(Loc, R_AARCH64_TLSIE_ADR_GOTTPREL_PAGE21, Val);
    break;
  case R_AARCH64_TLSDESC_LD64_LO12:
    write32le(Loc, 0xf9400000); // ldr
    relocateOne(Loc, R_AARCH64_TLSIE_LD64_GOTTPREL_LO12_NC, Val);
    break;
  default:
    llvm_unreachable("unsupported relocation for TLS GD to LE relaxation");
  }
}

void AArch64::relaxTlsIeToLe(uint8_t *Loc, uint32_t Type, uint64_t Val) const {
  checkUInt<32>(Loc, Val, Type);

  if (Type == R_AARCH64_TLSIE_ADR_GOTTPREL_PAGE21) {
    // Generate MOVZ.
    uint32_t RegNo = read32le(Loc) & 0x1f;
    write32le(Loc, (0xd2a00000 | RegNo) | (((Val >> 16) & 0xffff) << 5));
    return;
  }
  if (Type == R_AARCH64_TLSIE_LD64_GOTTPREL_LO12_NC) {
    // Generate MOVK.
    uint32_t RegNo = read32le(Loc) & 0x1f;
    write32le(Loc, (0xf2800000 | RegNo) | ((Val & 0xffff) << 5));
    return;
  }
  llvm_unreachable("invalid relocation for TLS IE to LE relaxation");
}

TargetInfo *elf::getAArch64TargetInfo() {
  static AArch64 Target;
  return &Target;
}
