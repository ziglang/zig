//===- ARM.cpp ------------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "Error.h"
#include "InputFiles.h"
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

namespace {
class ARM final : public TargetInfo {
public:
  ARM();
  RelExpr getRelExpr(uint32_t Type, const SymbolBody &S,
                     const uint8_t *Loc) const override;
  bool isPicRel(uint32_t Type) const override;
  uint32_t getDynRel(uint32_t Type) const override;
  int64_t getImplicitAddend(const uint8_t *Buf, uint32_t Type) const override;
  void writeGotPlt(uint8_t *Buf, const SymbolBody &S) const override;
  void writeIgotPlt(uint8_t *Buf, const SymbolBody &S) const override;
  void writePltHeader(uint8_t *Buf) const override;
  void writePlt(uint8_t *Buf, uint64_t GotPltEntryAddr, uint64_t PltEntryAddr,
                int32_t Index, unsigned RelOff) const override;
  void addPltSymbols(InputSectionBase *IS, uint64_t Off) const override;
  void addPltHeaderSymbols(InputSectionBase *ISD) const override;
  bool needsThunk(RelExpr Expr, uint32_t RelocType, const InputFile *File,
                  const SymbolBody &S) const override;
  bool inBranchRange(uint32_t RelocType, uint64_t Src,
                     uint64_t Dst) const override;
  void relocateOne(uint8_t *Loc, uint32_t Type, uint64_t Val) const override;
};
} // namespace

ARM::ARM() {
  CopyRel = R_ARM_COPY;
  RelativeRel = R_ARM_RELATIVE;
  IRelativeRel = R_ARM_IRELATIVE;
  GotRel = R_ARM_GLOB_DAT;
  PltRel = R_ARM_JUMP_SLOT;
  TlsGotRel = R_ARM_TLS_TPOFF32;
  TlsModuleIndexRel = R_ARM_TLS_DTPMOD32;
  TlsOffsetRel = R_ARM_TLS_DTPOFF32;
  GotEntrySize = 4;
  GotPltEntrySize = 4;
  PltEntrySize = 16;
  PltHeaderSize = 20;
  TrapInstr = 0xd4d4d4d4;
  // ARM uses Variant 1 TLS
  TcbSize = 8;
  NeedsThunks = true;
}

RelExpr ARM::getRelExpr(uint32_t Type, const SymbolBody &S,
                        const uint8_t *Loc) const {
  switch (Type) {
  default:
    return R_ABS;
  case R_ARM_THM_JUMP11:
    return R_PC;
  case R_ARM_CALL:
  case R_ARM_JUMP24:
  case R_ARM_PC24:
  case R_ARM_PLT32:
  case R_ARM_PREL31:
  case R_ARM_THM_JUMP19:
  case R_ARM_THM_JUMP24:
  case R_ARM_THM_CALL:
    return R_PLT_PC;
  case R_ARM_GOTOFF32:
    // (S + A) - GOT_ORG
    return R_GOTREL;
  case R_ARM_GOT_BREL:
    // GOT(S) + A - GOT_ORG
    return R_GOT_OFF;
  case R_ARM_GOT_PREL:
  case R_ARM_TLS_IE32:
    // GOT(S) + A - P
    return R_GOT_PC;
  case R_ARM_SBREL32:
    return R_ARM_SBREL;
  case R_ARM_TARGET1:
    return Config->Target1Rel ? R_PC : R_ABS;
  case R_ARM_TARGET2:
    if (Config->Target2 == Target2Policy::Rel)
      return R_PC;
    if (Config->Target2 == Target2Policy::Abs)
      return R_ABS;
    return R_GOT_PC;
  case R_ARM_TLS_GD32:
    return R_TLSGD_PC;
  case R_ARM_TLS_LDM32:
    return R_TLSLD_PC;
  case R_ARM_BASE_PREL:
    // B(S) + A - P
    // FIXME: currently B(S) assumed to be .got, this may not hold for all
    // platforms.
    return R_GOTONLY_PC;
  case R_ARM_MOVW_PREL_NC:
  case R_ARM_MOVT_PREL:
  case R_ARM_REL32:
  case R_ARM_THM_MOVW_PREL_NC:
  case R_ARM_THM_MOVT_PREL:
    return R_PC;
  case R_ARM_NONE:
    return R_NONE;
  case R_ARM_TLS_LE32:
    return R_TLS;
  }
}

bool ARM::isPicRel(uint32_t Type) const {
  return (Type == R_ARM_TARGET1 && !Config->Target1Rel) ||
         (Type == R_ARM_ABS32);
}

uint32_t ARM::getDynRel(uint32_t Type) const {
  if (Type == R_ARM_TARGET1 && !Config->Target1Rel)
    return R_ARM_ABS32;
  if (Type == R_ARM_ABS32)
    return Type;
  // Keep it going with a dummy value so that we can find more reloc errors.
  return R_ARM_ABS32;
}

void ARM::writeGotPlt(uint8_t *Buf, const SymbolBody &) const {
  write32le(Buf, InX::Plt->getVA());
}

void ARM::writeIgotPlt(uint8_t *Buf, const SymbolBody &S) const {
  // An ARM entry is the address of the ifunc resolver function.
  write32le(Buf, S.getVA());
}

void ARM::writePltHeader(uint8_t *Buf) const {
  const uint8_t PltData[] = {
      0x04, 0xe0, 0x2d, 0xe5, //     str lr, [sp,#-4]!
      0x04, 0xe0, 0x9f, 0xe5, //     ldr lr, L2
      0x0e, 0xe0, 0x8f, 0xe0, // L1: add lr, pc, lr
      0x08, 0xf0, 0xbe, 0xe5, //     ldr pc, [lr, #8]
      0x00, 0x00, 0x00, 0x00, // L2: .word   &(.got.plt) - L1 - 8
  };
  memcpy(Buf, PltData, sizeof(PltData));
  uint64_t GotPlt = InX::GotPlt->getVA();
  uint64_t L1 = InX::Plt->getVA() + 8;
  write32le(Buf + 16, GotPlt - L1 - 8);
}

void ARM::addPltHeaderSymbols(InputSectionBase *ISD) const {
  auto *IS = cast<InputSection>(ISD);
  addSyntheticLocal("$a", STT_NOTYPE, 0, 0, IS);
  addSyntheticLocal("$d", STT_NOTYPE, 16, 0, IS);
}

void ARM::writePlt(uint8_t *Buf, uint64_t GotPltEntryAddr,
                   uint64_t PltEntryAddr, int32_t Index,
                   unsigned RelOff) const {
  // FIXME: Using simple code sequence with simple relocations.
  // There is a more optimal sequence but it requires support for the group
  // relocations. See ELF for the ARM Architecture Appendix A.3
  const uint8_t PltData[] = {
      0x04, 0xc0, 0x9f, 0xe5, //     ldr ip, L2
      0x0f, 0xc0, 0x8c, 0xe0, // L1: add ip, ip, pc
      0x00, 0xf0, 0x9c, 0xe5, //     ldr pc, [ip]
      0x00, 0x00, 0x00, 0x00, // L2: .word   Offset(&(.plt.got) - L1 - 8
  };
  memcpy(Buf, PltData, sizeof(PltData));
  uint64_t L1 = PltEntryAddr + 4;
  write32le(Buf + 12, GotPltEntryAddr - L1 - 8);
}

void ARM::addPltSymbols(InputSectionBase *ISD, uint64_t Off) const {
  auto *IS = cast<InputSection>(ISD);
  addSyntheticLocal("$a", STT_NOTYPE, Off, 0, IS);
  addSyntheticLocal("$d", STT_NOTYPE, Off + 12, 0, IS);
}

bool ARM::needsThunk(RelExpr Expr, uint32_t RelocType, const InputFile *File,
                     const SymbolBody &S) const {
  // If S is an undefined weak symbol in an executable we don't need a Thunk.
  // In a DSO calls to undefined symbols, including weak ones get PLT entries
  // which may need a thunk.
  if (S.isUndefined() && !S.isLocal() && S.symbol()->isWeak() &&
      !Config->Shared)
    return false;
  // A state change from ARM to Thumb and vice versa must go through an
  // interworking thunk if the relocation type is not R_ARM_CALL or
  // R_ARM_THM_CALL.
  switch (RelocType) {
  case R_ARM_PC24:
  case R_ARM_PLT32:
  case R_ARM_JUMP24:
    // Source is ARM, all PLT entries are ARM so no interworking required.
    // Otherwise we need to interwork if Symbol has bit 0 set (Thumb).
    if (Expr == R_PC && ((S.getVA() & 1) == 1))
      return true;
    break;
  case R_ARM_THM_JUMP19:
  case R_ARM_THM_JUMP24:
    // Source is Thumb, all PLT entries are ARM so interworking is required.
    // Otherwise we need to interwork if Symbol has bit 0 clear (ARM).
    if (Expr == R_PLT_PC || ((S.getVA() & 1) == 0))
      return true;
    break;
  }
  return false;
}

bool ARM::inBranchRange(uint32_t RelocType, uint64_t Src, uint64_t Dst) const {
  uint64_t Range;
  uint64_t InstrSize;

  switch (RelocType) {
  case R_ARM_PC24:
  case R_ARM_PLT32:
  case R_ARM_JUMP24:
  case R_ARM_CALL:
    Range = 0x2000000;
    InstrSize = 4;
    break;
  case R_ARM_THM_JUMP19:
    Range = 0x100000;
    InstrSize = 2;
    break;
  case R_ARM_THM_JUMP24:
  case R_ARM_THM_CALL:
    Range = 0x1000000;
    InstrSize = 2;
    break;
  default:
    return true;
  }
  // PC at Src is 2 instructions ahead, immediate of branch is signed
  if (Src > Dst)
    Range -= 2 * InstrSize;
  else
    Range += InstrSize;

  if ((Dst & 0x1) == 0)
    // Destination is ARM, if ARM caller then Src is already 4-byte aligned.
    // If Thumb Caller (BLX) the Src address has bottom 2 bits cleared to ensure
    // destination will be 4 byte aligned.
    Src &= ~0x3;
  else
    // Bit 0 == 1 denotes Thumb state, it is not part of the range
    Dst &= ~0x1;

  uint64_t Distance = (Src > Dst) ? Src - Dst : Dst - Src;
  return Distance <= Range;
}

void ARM::relocateOne(uint8_t *Loc, uint32_t Type, uint64_t Val) const {
  switch (Type) {
  case R_ARM_ABS32:
  case R_ARM_BASE_PREL:
  case R_ARM_GLOB_DAT:
  case R_ARM_GOTOFF32:
  case R_ARM_GOT_BREL:
  case R_ARM_GOT_PREL:
  case R_ARM_REL32:
  case R_ARM_RELATIVE:
  case R_ARM_SBREL32:
  case R_ARM_TARGET1:
  case R_ARM_TARGET2:
  case R_ARM_TLS_GD32:
  case R_ARM_TLS_IE32:
  case R_ARM_TLS_LDM32:
  case R_ARM_TLS_LDO32:
  case R_ARM_TLS_LE32:
  case R_ARM_TLS_TPOFF32:
  case R_ARM_TLS_DTPOFF32:
    write32le(Loc, Val);
    break;
  case R_ARM_TLS_DTPMOD32:
    write32le(Loc, 1);
    break;
  case R_ARM_PREL31:
    checkInt<31>(Loc, Val, Type);
    write32le(Loc, (read32le(Loc) & 0x80000000) | (Val & ~0x80000000));
    break;
  case R_ARM_CALL:
    // R_ARM_CALL is used for BL and BLX instructions, depending on the
    // value of bit 0 of Val, we must select a BL or BLX instruction
    if (Val & 1) {
      // If bit 0 of Val is 1 the target is Thumb, we must select a BLX.
      // The BLX encoding is 0xfa:H:imm24 where Val = imm24:H:'1'
      checkInt<26>(Loc, Val, Type);
      write32le(Loc, 0xfa000000 |                    // opcode
                         ((Val & 2) << 23) |         // H
                         ((Val >> 2) & 0x00ffffff)); // imm24
      break;
    }
    if ((read32le(Loc) & 0xfe000000) == 0xfa000000)
      // BLX (always unconditional) instruction to an ARM Target, select an
      // unconditional BL.
      write32le(Loc, 0xeb000000 | (read32le(Loc) & 0x00ffffff));
    // fall through as BL encoding is shared with B
    LLVM_FALLTHROUGH;
  case R_ARM_JUMP24:
  case R_ARM_PC24:
  case R_ARM_PLT32:
    checkInt<26>(Loc, Val, Type);
    write32le(Loc, (read32le(Loc) & ~0x00ffffff) | ((Val >> 2) & 0x00ffffff));
    break;
  case R_ARM_THM_JUMP11:
    checkInt<12>(Loc, Val, Type);
    write16le(Loc, (read32le(Loc) & 0xf800) | ((Val >> 1) & 0x07ff));
    break;
  case R_ARM_THM_JUMP19:
    // Encoding T3: Val = S:J2:J1:imm6:imm11:0
    checkInt<21>(Loc, Val, Type);
    write16le(Loc,
              (read16le(Loc) & 0xfbc0) |   // opcode cond
                  ((Val >> 10) & 0x0400) | // S
                  ((Val >> 12) & 0x003f)); // imm6
    write16le(Loc + 2,
              0x8000 |                    // opcode
                  ((Val >> 8) & 0x0800) | // J2
                  ((Val >> 5) & 0x2000) | // J1
                  ((Val >> 1) & 0x07ff)); // imm11
    break;
  case R_ARM_THM_CALL:
    // R_ARM_THM_CALL is used for BL and BLX instructions, depending on the
    // value of bit 0 of Val, we must select a BL or BLX instruction
    if ((Val & 1) == 0) {
      // Ensure BLX destination is 4-byte aligned. As BLX instruction may
      // only be two byte aligned. This must be done before overflow check
      Val = alignTo(Val, 4);
    }
    // Bit 12 is 0 for BLX, 1 for BL
    write16le(Loc + 2, (read16le(Loc + 2) & ~0x1000) | (Val & 1) << 12);
    // Fall through as rest of encoding is the same as B.W
    LLVM_FALLTHROUGH;
  case R_ARM_THM_JUMP24:
    // Encoding B  T4, BL T1, BLX T2: Val = S:I1:I2:imm10:imm11:0
    // FIXME: Use of I1 and I2 require v6T2ops
    checkInt<25>(Loc, Val, Type);
    write16le(Loc,
              0xf000 |                     // opcode
                  ((Val >> 14) & 0x0400) | // S
                  ((Val >> 12) & 0x03ff)); // imm10
    write16le(Loc + 2,
              (read16le(Loc + 2) & 0xd000) |                  // opcode
                  (((~(Val >> 10)) ^ (Val >> 11)) & 0x2000) | // J1
                  (((~(Val >> 11)) ^ (Val >> 13)) & 0x0800) | // J2
                  ((Val >> 1) & 0x07ff));                     // imm11
    break;
  case R_ARM_MOVW_ABS_NC:
  case R_ARM_MOVW_PREL_NC:
    write32le(Loc, (read32le(Loc) & ~0x000f0fff) | ((Val & 0xf000) << 4) |
                       (Val & 0x0fff));
    break;
  case R_ARM_MOVT_ABS:
  case R_ARM_MOVT_PREL:
    checkInt<32>(Loc, Val, Type);
    write32le(Loc, (read32le(Loc) & ~0x000f0fff) |
                       (((Val >> 16) & 0xf000) << 4) | ((Val >> 16) & 0xfff));
    break;
  case R_ARM_THM_MOVT_ABS:
  case R_ARM_THM_MOVT_PREL:
    // Encoding T1: A = imm4:i:imm3:imm8
    checkInt<32>(Loc, Val, Type);
    write16le(Loc,
              0xf2c0 |                     // opcode
                  ((Val >> 17) & 0x0400) | // i
                  ((Val >> 28) & 0x000f)); // imm4
    write16le(Loc + 2,
              (read16le(Loc + 2) & 0x8f00) | // opcode
                  ((Val >> 12) & 0x7000) |   // imm3
                  ((Val >> 16) & 0x00ff));   // imm8
    break;
  case R_ARM_THM_MOVW_ABS_NC:
  case R_ARM_THM_MOVW_PREL_NC:
    // Encoding T3: A = imm4:i:imm3:imm8
    write16le(Loc,
              0xf240 |                     // opcode
                  ((Val >> 1) & 0x0400) |  // i
                  ((Val >> 12) & 0x000f)); // imm4
    write16le(Loc + 2,
              (read16le(Loc + 2) & 0x8f00) | // opcode
                  ((Val << 4) & 0x7000) |    // imm3
                  (Val & 0x00ff));           // imm8
    break;
  default:
    error(getErrorLocation(Loc) + "unrecognized reloc " + Twine(Type));
  }
}

int64_t ARM::getImplicitAddend(const uint8_t *Buf, uint32_t Type) const {
  switch (Type) {
  default:
    return 0;
  case R_ARM_ABS32:
  case R_ARM_BASE_PREL:
  case R_ARM_GOTOFF32:
  case R_ARM_GOT_BREL:
  case R_ARM_GOT_PREL:
  case R_ARM_REL32:
  case R_ARM_TARGET1:
  case R_ARM_TARGET2:
  case R_ARM_TLS_GD32:
  case R_ARM_TLS_LDM32:
  case R_ARM_TLS_LDO32:
  case R_ARM_TLS_IE32:
  case R_ARM_TLS_LE32:
    return SignExtend64<32>(read32le(Buf));
  case R_ARM_PREL31:
    return SignExtend64<31>(read32le(Buf));
  case R_ARM_CALL:
  case R_ARM_JUMP24:
  case R_ARM_PC24:
  case R_ARM_PLT32:
    return SignExtend64<26>(read32le(Buf) << 2);
  case R_ARM_THM_JUMP11:
    return SignExtend64<12>(read16le(Buf) << 1);
  case R_ARM_THM_JUMP19: {
    // Encoding T3: A = S:J2:J1:imm10:imm6:0
    uint16_t Hi = read16le(Buf);
    uint16_t Lo = read16le(Buf + 2);
    return SignExtend64<20>(((Hi & 0x0400) << 10) | // S
                            ((Lo & 0x0800) << 8) |  // J2
                            ((Lo & 0x2000) << 5) |  // J1
                            ((Hi & 0x003f) << 12) | // imm6
                            ((Lo & 0x07ff) << 1));  // imm11:0
  }
  case R_ARM_THM_CALL:
  case R_ARM_THM_JUMP24: {
    // Encoding B T4, BL T1, BLX T2: A = S:I1:I2:imm10:imm11:0
    // I1 = NOT(J1 EOR S), I2 = NOT(J2 EOR S)
    // FIXME: I1 and I2 require v6T2ops
    uint16_t Hi = read16le(Buf);
    uint16_t Lo = read16le(Buf + 2);
    return SignExtend64<24>(((Hi & 0x0400) << 14) |                    // S
                            (~((Lo ^ (Hi << 3)) << 10) & 0x00800000) | // I1
                            (~((Lo ^ (Hi << 1)) << 11) & 0x00400000) | // I2
                            ((Hi & 0x003ff) << 12) |                   // imm0
                            ((Lo & 0x007ff) << 1)); // imm11:0
  }
  // ELF for the ARM Architecture 4.6.1.1 the implicit addend for MOVW and
  // MOVT is in the range -32768 <= A < 32768
  case R_ARM_MOVW_ABS_NC:
  case R_ARM_MOVT_ABS:
  case R_ARM_MOVW_PREL_NC:
  case R_ARM_MOVT_PREL: {
    uint64_t Val = read32le(Buf) & 0x000f0fff;
    return SignExtend64<16>(((Val & 0x000f0000) >> 4) | (Val & 0x00fff));
  }
  case R_ARM_THM_MOVW_ABS_NC:
  case R_ARM_THM_MOVT_ABS:
  case R_ARM_THM_MOVW_PREL_NC:
  case R_ARM_THM_MOVT_PREL: {
    // Encoding T3: A = imm4:i:imm3:imm8
    uint16_t Hi = read16le(Buf);
    uint16_t Lo = read16le(Buf + 2);
    return SignExtend64<16>(((Hi & 0x000f) << 12) | // imm4
                            ((Hi & 0x0400) << 1) |  // i
                            ((Lo & 0x7000) >> 4) |  // imm3
                            (Lo & 0x00ff));         // imm8
  }
  }
}

TargetInfo *elf::getARMTargetInfo() {
  static ARM Target;
  return &Target;
}
