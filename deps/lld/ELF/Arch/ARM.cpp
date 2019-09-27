//===- ARM.cpp ------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "InputFiles.h"
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

namespace {
class ARM final : public TargetInfo {
public:
  ARM();
  uint32_t calcEFlags() const override;
  RelExpr getRelExpr(RelType type, const Symbol &s,
                     const uint8_t *loc) const override;
  RelType getDynRel(RelType type) const override;
  int64_t getImplicitAddend(const uint8_t *buf, RelType type) const override;
  void writeGotPlt(uint8_t *buf, const Symbol &s) const override;
  void writeIgotPlt(uint8_t *buf, const Symbol &s) const override;
  void writePltHeader(uint8_t *buf) const override;
  void writePlt(uint8_t *buf, uint64_t gotPltEntryAddr, uint64_t pltEntryAddr,
                int32_t index, unsigned relOff) const override;
  void addPltSymbols(InputSection &isec, uint64_t off) const override;
  void addPltHeaderSymbols(InputSection &isd) const override;
  bool needsThunk(RelExpr expr, RelType type, const InputFile *file,
                  uint64_t branchAddr, const Symbol &s) const override;
  uint32_t getThunkSectionSpacing() const override;
  bool inBranchRange(RelType type, uint64_t src, uint64_t dst) const override;
  void relocateOne(uint8_t *loc, RelType type, uint64_t val) const override;
};
} // namespace

ARM::ARM() {
  copyRel = R_ARM_COPY;
  relativeRel = R_ARM_RELATIVE;
  iRelativeRel = R_ARM_IRELATIVE;
  gotRel = R_ARM_GLOB_DAT;
  noneRel = R_ARM_NONE;
  pltRel = R_ARM_JUMP_SLOT;
  symbolicRel = R_ARM_ABS32;
  tlsGotRel = R_ARM_TLS_TPOFF32;
  tlsModuleIndexRel = R_ARM_TLS_DTPMOD32;
  tlsOffsetRel = R_ARM_TLS_DTPOFF32;
  gotBaseSymInGotPlt = false;
  pltEntrySize = 16;
  pltHeaderSize = 32;
  trapInstr = {0xd4, 0xd4, 0xd4, 0xd4};
  needsThunks = true;
}

uint32_t ARM::calcEFlags() const {
  // The ABIFloatType is used by loaders to detect the floating point calling
  // convention.
  uint32_t abiFloatType = 0;
  if (config->armVFPArgs == ARMVFPArgKind::Base ||
      config->armVFPArgs == ARMVFPArgKind::Default)
    abiFloatType = EF_ARM_ABI_FLOAT_SOFT;
  else if (config->armVFPArgs == ARMVFPArgKind::VFP)
    abiFloatType = EF_ARM_ABI_FLOAT_HARD;

  // We don't currently use any features incompatible with EF_ARM_EABI_VER5,
  // but we don't have any firm guarantees of conformance. Linux AArch64
  // kernels (as of 2016) require an EABI version to be set.
  return EF_ARM_EABI_VER5 | abiFloatType;
}

RelExpr ARM::getRelExpr(RelType type, const Symbol &s,
                        const uint8_t *loc) const {
  switch (type) {
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
    return config->target1Rel ? R_PC : R_ABS;
  case R_ARM_TARGET2:
    if (config->target2 == Target2Policy::Rel)
      return R_PC;
    if (config->target2 == Target2Policy::Abs)
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
  case R_ARM_V4BX:
    // V4BX is just a marker to indicate there's a "bx rN" instruction at the
    // given address. It can be used to implement a special linker mode which
    // rewrites ARMv4T inputs to ARMv4. Since we support only ARMv4 input and
    // not ARMv4 output, we can just ignore it.
    return R_HINT;
  default:
    return R_ABS;
  }
}

RelType ARM::getDynRel(RelType type) const {
  if ((type == R_ARM_ABS32) || (type == R_ARM_TARGET1 && !config->target1Rel))
    return R_ARM_ABS32;
  return R_ARM_NONE;
}

void ARM::writeGotPlt(uint8_t *buf, const Symbol &) const {
  write32le(buf, in.plt->getVA());
}

void ARM::writeIgotPlt(uint8_t *buf, const Symbol &s) const {
  // An ARM entry is the address of the ifunc resolver function.
  write32le(buf, s.getVA());
}

// Long form PLT Header that does not have any restrictions on the displacement
// of the .plt from the .plt.got.
static void writePltHeaderLong(uint8_t *buf) {
  const uint8_t pltData[] = {
      0x04, 0xe0, 0x2d, 0xe5, //     str lr, [sp,#-4]!
      0x04, 0xe0, 0x9f, 0xe5, //     ldr lr, L2
      0x0e, 0xe0, 0x8f, 0xe0, // L1: add lr, pc, lr
      0x08, 0xf0, 0xbe, 0xe5, //     ldr pc, [lr, #8]
      0x00, 0x00, 0x00, 0x00, // L2: .word   &(.got.plt) - L1 - 8
      0xd4, 0xd4, 0xd4, 0xd4, //     Pad to 32-byte boundary
      0xd4, 0xd4, 0xd4, 0xd4, //     Pad to 32-byte boundary
      0xd4, 0xd4, 0xd4, 0xd4};
  memcpy(buf, pltData, sizeof(pltData));
  uint64_t gotPlt = in.gotPlt->getVA();
  uint64_t l1 = in.plt->getVA() + 8;
  write32le(buf + 16, gotPlt - l1 - 8);
}

// The default PLT header requires the .plt.got to be within 128 Mb of the
// .plt in the positive direction.
void ARM::writePltHeader(uint8_t *buf) const {
  // Use a similar sequence to that in writePlt(), the difference is the calling
  // conventions mean we use lr instead of ip. The PLT entry is responsible for
  // saving lr on the stack, the dynamic loader is responsible for reloading
  // it.
  const uint32_t pltData[] = {
      0xe52de004, // L1: str lr, [sp,#-4]!
      0xe28fe600, //     add lr, pc,  #0x0NN00000 &(.got.plt - L1 - 4)
      0xe28eea00, //     add lr, lr,  #0x000NN000 &(.got.plt - L1 - 4)
      0xe5bef000, //     ldr pc, [lr, #0x00000NNN] &(.got.plt -L1 - 4)
  };

  uint64_t offset = in.gotPlt->getVA() - in.plt->getVA() - 4;
  if (!llvm::isUInt<27>(offset)) {
    // We cannot encode the Offset, use the long form.
    writePltHeaderLong(buf);
    return;
  }
  write32le(buf + 0, pltData[0]);
  write32le(buf + 4, pltData[1] | ((offset >> 20) & 0xff));
  write32le(buf + 8, pltData[2] | ((offset >> 12) & 0xff));
  write32le(buf + 12, pltData[3] | (offset & 0xfff));
  memcpy(buf + 16, trapInstr.data(), 4); // Pad to 32-byte boundary
  memcpy(buf + 20, trapInstr.data(), 4);
  memcpy(buf + 24, trapInstr.data(), 4);
  memcpy(buf + 28, trapInstr.data(), 4);
}

void ARM::addPltHeaderSymbols(InputSection &isec) const {
  addSyntheticLocal("$a", STT_NOTYPE, 0, 0, isec);
  addSyntheticLocal("$d", STT_NOTYPE, 16, 0, isec);
}

// Long form PLT entries that do not have any restrictions on the displacement
// of the .plt from the .plt.got.
static void writePltLong(uint8_t *buf, uint64_t gotPltEntryAddr,
                         uint64_t pltEntryAddr, int32_t index,
                         unsigned relOff) {
  const uint8_t pltData[] = {
      0x04, 0xc0, 0x9f, 0xe5, //     ldr ip, L2
      0x0f, 0xc0, 0x8c, 0xe0, // L1: add ip, ip, pc
      0x00, 0xf0, 0x9c, 0xe5, //     ldr pc, [ip]
      0x00, 0x00, 0x00, 0x00, // L2: .word   Offset(&(.plt.got) - L1 - 8
  };
  memcpy(buf, pltData, sizeof(pltData));
  uint64_t l1 = pltEntryAddr + 4;
  write32le(buf + 12, gotPltEntryAddr - l1 - 8);
}

// The default PLT entries require the .plt.got to be within 128 Mb of the
// .plt in the positive direction.
void ARM::writePlt(uint8_t *buf, uint64_t gotPltEntryAddr,
                   uint64_t pltEntryAddr, int32_t index,
                   unsigned relOff) const {
  // The PLT entry is similar to the example given in Appendix A of ELF for
  // the Arm Architecture. Instead of using the Group Relocations to find the
  // optimal rotation for the 8-bit immediate used in the add instructions we
  // hard code the most compact rotations for simplicity. This saves a load
  // instruction over the long plt sequences.
  const uint32_t pltData[] = {
      0xe28fc600, // L1: add ip, pc,  #0x0NN00000  Offset(&(.plt.got) - L1 - 8
      0xe28cca00, //     add ip, ip,  #0x000NN000  Offset(&(.plt.got) - L1 - 8
      0xe5bcf000, //     ldr pc, [ip, #0x00000NNN] Offset(&(.plt.got) - L1 - 8
  };

  uint64_t offset = gotPltEntryAddr - pltEntryAddr - 8;
  if (!llvm::isUInt<27>(offset)) {
    // We cannot encode the Offset, use the long form.
    writePltLong(buf, gotPltEntryAddr, pltEntryAddr, index, relOff);
    return;
  }
  write32le(buf + 0, pltData[0] | ((offset >> 20) & 0xff));
  write32le(buf + 4, pltData[1] | ((offset >> 12) & 0xff));
  write32le(buf + 8, pltData[2] | (offset & 0xfff));
  memcpy(buf + 12, trapInstr.data(), 4); // Pad to 16-byte boundary
}

void ARM::addPltSymbols(InputSection &isec, uint64_t off) const {
  addSyntheticLocal("$a", STT_NOTYPE, off, 0, isec);
  addSyntheticLocal("$d", STT_NOTYPE, off + 12, 0, isec);
}

bool ARM::needsThunk(RelExpr expr, RelType type, const InputFile *file,
                     uint64_t branchAddr, const Symbol &s) const {
  // If S is an undefined weak symbol and does not have a PLT entry then it
  // will be resolved as a branch to the next instruction.
  if (s.isUndefWeak() && !s.isInPlt())
    return false;
  // A state change from ARM to Thumb and vice versa must go through an
  // interworking thunk if the relocation type is not R_ARM_CALL or
  // R_ARM_THM_CALL.
  switch (type) {
  case R_ARM_PC24:
  case R_ARM_PLT32:
  case R_ARM_JUMP24:
    // Source is ARM, all PLT entries are ARM so no interworking required.
    // Otherwise we need to interwork if Symbol has bit 0 set (Thumb).
    if (expr == R_PC && ((s.getVA() & 1) == 1))
      return true;
    LLVM_FALLTHROUGH;
  case R_ARM_CALL: {
    uint64_t dst = (expr == R_PLT_PC) ? s.getPltVA() : s.getVA();
    return !inBranchRange(type, branchAddr, dst);
  }
  case R_ARM_THM_JUMP19:
  case R_ARM_THM_JUMP24:
    // Source is Thumb, all PLT entries are ARM so interworking is required.
    // Otherwise we need to interwork if Symbol has bit 0 clear (ARM).
    if (expr == R_PLT_PC || ((s.getVA() & 1) == 0))
      return true;
    LLVM_FALLTHROUGH;
  case R_ARM_THM_CALL: {
    uint64_t dst = (expr == R_PLT_PC) ? s.getPltVA() : s.getVA();
    return !inBranchRange(type, branchAddr, dst);
  }
  }
  return false;
}

uint32_t ARM::getThunkSectionSpacing() const {
  // The placing of pre-created ThunkSections is controlled by the value
  // thunkSectionSpacing returned by getThunkSectionSpacing(). The aim is to
  // place the ThunkSection such that all branches from the InputSections
  // prior to the ThunkSection can reach a Thunk placed at the end of the
  // ThunkSection. Graphically:
  // | up to thunkSectionSpacing .text input sections |
  // | ThunkSection                                   |
  // | up to thunkSectionSpacing .text input sections |
  // | ThunkSection                                   |

  // Pre-created ThunkSections are spaced roughly 16MiB apart on ARMv7. This
  // is to match the most common expected case of a Thumb 2 encoded BL, BLX or
  // B.W:
  // ARM B, BL, BLX range +/- 32MiB
  // Thumb B.W, BL, BLX range +/- 16MiB
  // Thumb B<cc>.W range +/- 1MiB
  // If a branch cannot reach a pre-created ThunkSection a new one will be
  // created so we can handle the rare cases of a Thumb 2 conditional branch.
  // We intentionally use a lower size for thunkSectionSpacing than the maximum
  // branch range so the end of the ThunkSection is more likely to be within
  // range of the branch instruction that is furthest away. The value we shorten
  // thunkSectionSpacing by is set conservatively to allow us to create 16,384
  // 12 byte Thunks at any offset in a ThunkSection without risk of a branch to
  // one of the Thunks going out of range.

  // On Arm the thunkSectionSpacing depends on the range of the Thumb Branch
  // range. On earlier Architectures such as ARMv4, ARMv5 and ARMv6 (except
  // ARMv6T2) the range is +/- 4MiB.

  return (config->armJ1J2BranchEncoding) ? 0x1000000 - 0x30000
                                         : 0x400000 - 0x7500;
}

bool ARM::inBranchRange(RelType type, uint64_t src, uint64_t dst) const {
  uint64_t range;
  uint64_t instrSize;

  switch (type) {
  case R_ARM_PC24:
  case R_ARM_PLT32:
  case R_ARM_JUMP24:
  case R_ARM_CALL:
    range = 0x2000000;
    instrSize = 4;
    break;
  case R_ARM_THM_JUMP19:
    range = 0x100000;
    instrSize = 2;
    break;
  case R_ARM_THM_JUMP24:
  case R_ARM_THM_CALL:
    range = config->armJ1J2BranchEncoding ? 0x1000000 : 0x400000;
    instrSize = 2;
    break;
  default:
    return true;
  }
  // PC at Src is 2 instructions ahead, immediate of branch is signed
  if (src > dst)
    range -= 2 * instrSize;
  else
    range += instrSize;

  if ((dst & 0x1) == 0)
    // Destination is ARM, if ARM caller then Src is already 4-byte aligned.
    // If Thumb Caller (BLX) the Src address has bottom 2 bits cleared to ensure
    // destination will be 4 byte aligned.
    src &= ~0x3;
  else
    // Bit 0 == 1 denotes Thumb state, it is not part of the range
    dst &= ~0x1;

  uint64_t distance = (src > dst) ? src - dst : dst - src;
  return distance <= range;
}

void ARM::relocateOne(uint8_t *loc, RelType type, uint64_t val) const {
  switch (type) {
  case R_ARM_ABS32:
  case R_ARM_BASE_PREL:
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
    write32le(loc, val);
    break;
  case R_ARM_PREL31:
    checkInt(loc, val, 31, type);
    write32le(loc, (read32le(loc) & 0x80000000) | (val & ~0x80000000));
    break;
  case R_ARM_CALL:
    // R_ARM_CALL is used for BL and BLX instructions, depending on the
    // value of bit 0 of Val, we must select a BL or BLX instruction
    if (val & 1) {
      // If bit 0 of Val is 1 the target is Thumb, we must select a BLX.
      // The BLX encoding is 0xfa:H:imm24 where Val = imm24:H:'1'
      checkInt(loc, val, 26, type);
      write32le(loc, 0xfa000000 |                    // opcode
                         ((val & 2) << 23) |         // H
                         ((val >> 2) & 0x00ffffff)); // imm24
      break;
    }
    if ((read32le(loc) & 0xfe000000) == 0xfa000000)
      // BLX (always unconditional) instruction to an ARM Target, select an
      // unconditional BL.
      write32le(loc, 0xeb000000 | (read32le(loc) & 0x00ffffff));
    // fall through as BL encoding is shared with B
    LLVM_FALLTHROUGH;
  case R_ARM_JUMP24:
  case R_ARM_PC24:
  case R_ARM_PLT32:
    checkInt(loc, val, 26, type);
    write32le(loc, (read32le(loc) & ~0x00ffffff) | ((val >> 2) & 0x00ffffff));
    break;
  case R_ARM_THM_JUMP11:
    checkInt(loc, val, 12, type);
    write16le(loc, (read32le(loc) & 0xf800) | ((val >> 1) & 0x07ff));
    break;
  case R_ARM_THM_JUMP19:
    // Encoding T3: Val = S:J2:J1:imm6:imm11:0
    checkInt(loc, val, 21, type);
    write16le(loc,
              (read16le(loc) & 0xfbc0) |   // opcode cond
                  ((val >> 10) & 0x0400) | // S
                  ((val >> 12) & 0x003f)); // imm6
    write16le(loc + 2,
              0x8000 |                    // opcode
                  ((val >> 8) & 0x0800) | // J2
                  ((val >> 5) & 0x2000) | // J1
                  ((val >> 1) & 0x07ff)); // imm11
    break;
  case R_ARM_THM_CALL:
    // R_ARM_THM_CALL is used for BL and BLX instructions, depending on the
    // value of bit 0 of Val, we must select a BL or BLX instruction
    if ((val & 1) == 0) {
      // Ensure BLX destination is 4-byte aligned. As BLX instruction may
      // only be two byte aligned. This must be done before overflow check
      val = alignTo(val, 4);
    }
    // Bit 12 is 0 for BLX, 1 for BL
    write16le(loc + 2, (read16le(loc + 2) & ~0x1000) | (val & 1) << 12);
    if (!config->armJ1J2BranchEncoding) {
      // Older Arm architectures do not support R_ARM_THM_JUMP24 and have
      // different encoding rules and range due to J1 and J2 always being 1.
      checkInt(loc, val, 23, type);
      write16le(loc,
                0xf000 |                     // opcode
                    ((val >> 12) & 0x07ff)); // imm11
      write16le(loc + 2,
                (read16le(loc + 2) & 0xd000) | // opcode
                    0x2800 |                   // J1 == J2 == 1
                    ((val >> 1) & 0x07ff));    // imm11
      break;
    }
    // Fall through as rest of encoding is the same as B.W
    LLVM_FALLTHROUGH;
  case R_ARM_THM_JUMP24:
    // Encoding B  T4, BL T1, BLX T2: Val = S:I1:I2:imm10:imm11:0
    checkInt(loc, val, 25, type);
    write16le(loc,
              0xf000 |                     // opcode
                  ((val >> 14) & 0x0400) | // S
                  ((val >> 12) & 0x03ff)); // imm10
    write16le(loc + 2,
              (read16le(loc + 2) & 0xd000) |                  // opcode
                  (((~(val >> 10)) ^ (val >> 11)) & 0x2000) | // J1
                  (((~(val >> 11)) ^ (val >> 13)) & 0x0800) | // J2
                  ((val >> 1) & 0x07ff));                     // imm11
    break;
  case R_ARM_MOVW_ABS_NC:
  case R_ARM_MOVW_PREL_NC:
    write32le(loc, (read32le(loc) & ~0x000f0fff) | ((val & 0xf000) << 4) |
                       (val & 0x0fff));
    break;
  case R_ARM_MOVT_ABS:
  case R_ARM_MOVT_PREL:
    write32le(loc, (read32le(loc) & ~0x000f0fff) |
                       (((val >> 16) & 0xf000) << 4) | ((val >> 16) & 0xfff));
    break;
  case R_ARM_THM_MOVT_ABS:
  case R_ARM_THM_MOVT_PREL:
    // Encoding T1: A = imm4:i:imm3:imm8
    write16le(loc,
              0xf2c0 |                     // opcode
                  ((val >> 17) & 0x0400) | // i
                  ((val >> 28) & 0x000f)); // imm4
    write16le(loc + 2,
              (read16le(loc + 2) & 0x8f00) | // opcode
                  ((val >> 12) & 0x7000) |   // imm3
                  ((val >> 16) & 0x00ff));   // imm8
    break;
  case R_ARM_THM_MOVW_ABS_NC:
  case R_ARM_THM_MOVW_PREL_NC:
    // Encoding T3: A = imm4:i:imm3:imm8
    write16le(loc,
              0xf240 |                     // opcode
                  ((val >> 1) & 0x0400) |  // i
                  ((val >> 12) & 0x000f)); // imm4
    write16le(loc + 2,
              (read16le(loc + 2) & 0x8f00) | // opcode
                  ((val << 4) & 0x7000) |    // imm3
                  (val & 0x00ff));           // imm8
    break;
  default:
    error(getErrorLocation(loc) + "unrecognized relocation " + toString(type));
  }
}

int64_t ARM::getImplicitAddend(const uint8_t *buf, RelType type) const {
  switch (type) {
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
    return SignExtend64<32>(read32le(buf));
  case R_ARM_PREL31:
    return SignExtend64<31>(read32le(buf));
  case R_ARM_CALL:
  case R_ARM_JUMP24:
  case R_ARM_PC24:
  case R_ARM_PLT32:
    return SignExtend64<26>(read32le(buf) << 2);
  case R_ARM_THM_JUMP11:
    return SignExtend64<12>(read16le(buf) << 1);
  case R_ARM_THM_JUMP19: {
    // Encoding T3: A = S:J2:J1:imm10:imm6:0
    uint16_t hi = read16le(buf);
    uint16_t lo = read16le(buf + 2);
    return SignExtend64<20>(((hi & 0x0400) << 10) | // S
                            ((lo & 0x0800) << 8) |  // J2
                            ((lo & 0x2000) << 5) |  // J1
                            ((hi & 0x003f) << 12) | // imm6
                            ((lo & 0x07ff) << 1));  // imm11:0
  }
  case R_ARM_THM_CALL:
    if (!config->armJ1J2BranchEncoding) {
      // Older Arm architectures do not support R_ARM_THM_JUMP24 and have
      // different encoding rules and range due to J1 and J2 always being 1.
      uint16_t hi = read16le(buf);
      uint16_t lo = read16le(buf + 2);
      return SignExtend64<22>(((hi & 0x7ff) << 12) | // imm11
                              ((lo & 0x7ff) << 1));  // imm11:0
      break;
    }
    LLVM_FALLTHROUGH;
  case R_ARM_THM_JUMP24: {
    // Encoding B T4, BL T1, BLX T2: A = S:I1:I2:imm10:imm11:0
    // I1 = NOT(J1 EOR S), I2 = NOT(J2 EOR S)
    uint16_t hi = read16le(buf);
    uint16_t lo = read16le(buf + 2);
    return SignExtend64<24>(((hi & 0x0400) << 14) |                    // S
                            (~((lo ^ (hi << 3)) << 10) & 0x00800000) | // I1
                            (~((lo ^ (hi << 1)) << 11) & 0x00400000) | // I2
                            ((hi & 0x003ff) << 12) |                   // imm0
                            ((lo & 0x007ff) << 1)); // imm11:0
  }
  // ELF for the ARM Architecture 4.6.1.1 the implicit addend for MOVW and
  // MOVT is in the range -32768 <= A < 32768
  case R_ARM_MOVW_ABS_NC:
  case R_ARM_MOVT_ABS:
  case R_ARM_MOVW_PREL_NC:
  case R_ARM_MOVT_PREL: {
    uint64_t val = read32le(buf) & 0x000f0fff;
    return SignExtend64<16>(((val & 0x000f0000) >> 4) | (val & 0x00fff));
  }
  case R_ARM_THM_MOVW_ABS_NC:
  case R_ARM_THM_MOVT_ABS:
  case R_ARM_THM_MOVW_PREL_NC:
  case R_ARM_THM_MOVT_PREL: {
    // Encoding T3: A = imm4:i:imm3:imm8
    uint16_t hi = read16le(buf);
    uint16_t lo = read16le(buf + 2);
    return SignExtend64<16>(((hi & 0x000f) << 12) | // imm4
                            ((hi & 0x0400) << 1) |  // i
                            ((lo & 0x7000) >> 4) |  // imm3
                            (lo & 0x00ff));         // imm8
  }
  }
}

TargetInfo *elf::getARMTargetInfo() {
  static ARM target;
  return &target;
}
