//===- Thunks.cpp --------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===---------------------------------------------------------------------===//
//
// This file contains Thunk subclasses.
//
// A thunk is a small piece of code written after an input section
// which is used to jump between "incompatible" functions
// such as MIPS PIC and non-PIC or ARM non-Thumb and Thumb functions.
//
// If a jump target is too far and its address doesn't fit to a
// short jump instruction, we need to create a thunk too, but we
// haven't supported it yet.
//
// i386 and x86-64 don't need thunks.
//
//===---------------------------------------------------------------------===//

#include "Thunks.h"
#include "Config.h"
#include "InputSection.h"
#include "OutputSections.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/MathExtras.h"
#include <cstdint>
#include <cstring>

using namespace llvm;
using namespace llvm::object;
using namespace llvm::support::endian;
using namespace llvm::ELF;

namespace lld {
namespace elf {

namespace {

// AArch64 long range Thunks
class AArch64ABSLongThunk final : public Thunk {
public:
  AArch64ABSLongThunk(Symbol &Dest) : Thunk(Dest) {}
  uint32_t size() const override { return 16; }
  void writeTo(uint8_t *Buf, ThunkSection &IS) const override;
  void addSymbols(ThunkSection &IS) override;
};

class AArch64ADRPThunk final : public Thunk {
public:
  AArch64ADRPThunk(Symbol &Dest) : Thunk(Dest) {}
  uint32_t size() const override { return 12; }
  void writeTo(uint8_t *Buf, ThunkSection &IS) const override;
  void addSymbols(ThunkSection &IS) override;
};

// Specific ARM Thunk implementations. The naming convention is:
// Source State, TargetState, Target Requirement, ABS or PI, Range
class ARMV7ABSLongThunk final : public Thunk {
public:
  ARMV7ABSLongThunk(Symbol &Dest) : Thunk(Dest) {}

  uint32_t size() const override { return 12; }
  void writeTo(uint8_t *Buf, ThunkSection &IS) const override;
  void addSymbols(ThunkSection &IS) override;
  bool isCompatibleWith(RelType Type) const override;
};

class ARMV7PILongThunk final : public Thunk {
public:
  ARMV7PILongThunk(Symbol &Dest) : Thunk(Dest) {}

  uint32_t size() const override { return 16; }
  void writeTo(uint8_t *Buf, ThunkSection &IS) const override;
  void addSymbols(ThunkSection &IS) override;
  bool isCompatibleWith(RelType Type) const override;
};

class ThumbV7ABSLongThunk final : public Thunk {
public:
  ThumbV7ABSLongThunk(Symbol &Dest) : Thunk(Dest) { Alignment = 2; }

  uint32_t size() const override { return 10; }
  void writeTo(uint8_t *Buf, ThunkSection &IS) const override;
  void addSymbols(ThunkSection &IS) override;
  bool isCompatibleWith(RelType Type) const override;
};

class ThumbV7PILongThunk final : public Thunk {
public:
  ThumbV7PILongThunk(Symbol &Dest) : Thunk(Dest) { Alignment = 2; }

  uint32_t size() const override { return 12; }
  void writeTo(uint8_t *Buf, ThunkSection &IS) const override;
  void addSymbols(ThunkSection &IS) override;
  bool isCompatibleWith(RelType Type) const override;
};

// MIPS LA25 thunk
class MipsThunk final : public Thunk {
public:
  MipsThunk(Symbol &Dest) : Thunk(Dest) {}

  uint32_t size() const override { return 16; }
  void writeTo(uint8_t *Buf, ThunkSection &IS) const override;
  void addSymbols(ThunkSection &IS) override;
  InputSection *getTargetInputSection() const override;
};

// microMIPS R2-R5 LA25 thunk
class MicroMipsThunk final : public Thunk {
public:
  MicroMipsThunk(Symbol &Dest) : Thunk(Dest) {}

  uint32_t size() const override { return 14; }
  void writeTo(uint8_t *Buf, ThunkSection &IS) const override;
  void addSymbols(ThunkSection &IS) override;
  InputSection *getTargetInputSection() const override;
};

// microMIPS R6 LA25 thunk
class MicroMipsR6Thunk final : public Thunk {
public:
  MicroMipsR6Thunk(Symbol &Dest) : Thunk(Dest) {}

  uint32_t size() const override { return 12; }
  void writeTo(uint8_t *Buf, ThunkSection &IS) const override;
  void addSymbols(ThunkSection &IS) override;
  InputSection *getTargetInputSection() const override;
};

} // end anonymous namespace

// AArch64 long range Thunks

static uint64_t getAArch64ThunkDestVA(const Symbol &S) {
  uint64_t V = S.isInPlt() ? S.getPltVA() : S.getVA();
  return V;
}

void AArch64ABSLongThunk::writeTo(uint8_t *Buf, ThunkSection &IS) const {
  const uint8_t Data[] = {
    0x50, 0x00, 0x00, 0x58, //     ldr x16, L0
    0x00, 0x02, 0x1f, 0xd6, //     br  x16
    0x00, 0x00, 0x00, 0x00, // L0: .xword S
    0x00, 0x00, 0x00, 0x00,
  };
  uint64_t S = getAArch64ThunkDestVA(Destination);
  memcpy(Buf, Data, sizeof(Data));
  Target->relocateOne(Buf + 8, R_AARCH64_ABS64, S);
}

void AArch64ABSLongThunk::addSymbols(ThunkSection &IS) {
  ThunkSym = addSyntheticLocal(
      Saver.save("__AArch64AbsLongThunk_" + Destination.getName()), STT_FUNC,
      Offset, size(), IS);
  addSyntheticLocal("$x", STT_NOTYPE, Offset, 0, IS);
  addSyntheticLocal("$d", STT_NOTYPE, Offset + 8, 0, IS);
}

// This Thunk has a maximum range of 4Gb, this is sufficient for all programs
// using the small code model, including pc-relative ones. At time of writing
// clang and gcc do not support the large code model for position independent
// code so it is safe to use this for position independent thunks without
// worrying about the destination being more than 4Gb away.
void AArch64ADRPThunk::writeTo(uint8_t *Buf, ThunkSection &IS) const {
  const uint8_t Data[] = {
      0x10, 0x00, 0x00, 0x90, // adrp x16, Dest R_AARCH64_ADR_PREL_PG_HI21(Dest)
      0x10, 0x02, 0x00, 0x91, // add  x16, x16, R_AARCH64_ADD_ABS_LO12_NC(Dest)
      0x00, 0x02, 0x1f, 0xd6, // br   x16
  };
  uint64_t S = getAArch64ThunkDestVA(Destination);
  uint64_t P = ThunkSym->getVA();
  memcpy(Buf, Data, sizeof(Data));
  Target->relocateOne(Buf, R_AARCH64_ADR_PREL_PG_HI21,
                      getAArch64Page(S) - getAArch64Page(P));
  Target->relocateOne(Buf + 4, R_AARCH64_ADD_ABS_LO12_NC, S);
}

void AArch64ADRPThunk::addSymbols(ThunkSection &IS)
{
  ThunkSym = addSyntheticLocal(
      Saver.save("__AArch64ADRPThunk_" + Destination.getName()), STT_FUNC,
      Offset, size(), IS);
  addSyntheticLocal("$x", STT_NOTYPE, Offset, 0, IS);
}

// ARM Target Thunks
static uint64_t getARMThunkDestVA(const Symbol &S) {
  uint64_t V = S.isInPlt() ? S.getPltVA() : S.getVA();
  return SignExtend64<32>(V);
}

void ARMV7ABSLongThunk::writeTo(uint8_t *Buf, ThunkSection &IS) const {
  const uint8_t Data[] = {
      0x00, 0xc0, 0x00, 0xe3, // movw         ip,:lower16:S
      0x00, 0xc0, 0x40, 0xe3, // movt         ip,:upper16:S
      0x1c, 0xff, 0x2f, 0xe1, // bx   ip
  };
  uint64_t S = getARMThunkDestVA(Destination);
  memcpy(Buf, Data, sizeof(Data));
  Target->relocateOne(Buf, R_ARM_MOVW_ABS_NC, S);
  Target->relocateOne(Buf + 4, R_ARM_MOVT_ABS, S);
}

void ARMV7ABSLongThunk::addSymbols(ThunkSection &IS) {
  ThunkSym = addSyntheticLocal(
      Saver.save("__ARMv7ABSLongThunk_" + Destination.getName()), STT_FUNC,
      Offset, size(), IS);
  addSyntheticLocal("$a", STT_NOTYPE, Offset, 0, IS);
}

bool ARMV7ABSLongThunk::isCompatibleWith(RelType Type) const {
  // Thumb branch relocations can't use BLX
  return Type != R_ARM_THM_JUMP19 && Type != R_ARM_THM_JUMP24;
}

void ThumbV7ABSLongThunk::writeTo(uint8_t *Buf, ThunkSection &IS) const {
  const uint8_t Data[] = {
      0x40, 0xf2, 0x00, 0x0c, // movw         ip, :lower16:S
      0xc0, 0xf2, 0x00, 0x0c, // movt         ip, :upper16:S
      0x60, 0x47,             // bx   ip
  };
  uint64_t S = getARMThunkDestVA(Destination);
  memcpy(Buf, Data, sizeof(Data));
  Target->relocateOne(Buf, R_ARM_THM_MOVW_ABS_NC, S);
  Target->relocateOne(Buf + 4, R_ARM_THM_MOVT_ABS, S);
}

void ThumbV7ABSLongThunk::addSymbols(ThunkSection &IS) {
  ThunkSym = addSyntheticLocal(
      Saver.save("__Thumbv7ABSLongThunk_" + Destination.getName()), STT_FUNC,
      Offset | 0x1, size(), IS);
  addSyntheticLocal("$t", STT_NOTYPE, Offset, 0, IS);
}

bool ThumbV7ABSLongThunk::isCompatibleWith(RelType Type) const {
  // ARM branch relocations can't use BLX
  return Type != R_ARM_JUMP24 && Type != R_ARM_PC24 && Type != R_ARM_PLT32;
}

void ARMV7PILongThunk::writeTo(uint8_t *Buf, ThunkSection &IS) const {
  const uint8_t Data[] = {
      0xf0, 0xcf, 0x0f, 0xe3, // P:  movw ip,:lower16:S - (P + (L1-P) + 8)
      0x00, 0xc0, 0x40, 0xe3, //     movt ip,:upper16:S - (P + (L1-P) + 8)
      0x0f, 0xc0, 0x8c, 0xe0, // L1: add ip, ip, pc
      0x1c, 0xff, 0x2f, 0xe1, //     bx r12
  };
  uint64_t S = getARMThunkDestVA(Destination);
  uint64_t P = ThunkSym->getVA();
  uint64_t Offset = S - P - 16;
  memcpy(Buf, Data, sizeof(Data));
  Target->relocateOne(Buf, R_ARM_MOVW_PREL_NC, Offset);
  Target->relocateOne(Buf + 4, R_ARM_MOVT_PREL, Offset);
}

void ARMV7PILongThunk::addSymbols(ThunkSection &IS) {
  ThunkSym = addSyntheticLocal(
      Saver.save("__ARMV7PILongThunk_" + Destination.getName()), STT_FUNC,
      Offset, size(), IS);
  addSyntheticLocal("$a", STT_NOTYPE, Offset, 0, IS);
}

bool ARMV7PILongThunk::isCompatibleWith(RelType Type) const {
  // Thumb branch relocations can't use BLX
  return Type != R_ARM_THM_JUMP19 && Type != R_ARM_THM_JUMP24;
}

void ThumbV7PILongThunk::writeTo(uint8_t *Buf, ThunkSection &IS) const {
  const uint8_t Data[] = {
      0x4f, 0xf6, 0xf4, 0x7c, // P:  movw ip,:lower16:S - (P + (L1-P) + 4)
      0xc0, 0xf2, 0x00, 0x0c, //     movt ip,:upper16:S - (P + (L1-P) + 4)
      0xfc, 0x44,             // L1: add  r12, pc
      0x60, 0x47,             //     bx   r12
  };
  uint64_t S = getARMThunkDestVA(Destination);
  uint64_t P = ThunkSym->getVA() & ~0x1;
  uint64_t Offset = S - P - 12;
  memcpy(Buf, Data, sizeof(Data));
  Target->relocateOne(Buf, R_ARM_THM_MOVW_PREL_NC, Offset);
  Target->relocateOne(Buf + 4, R_ARM_THM_MOVT_PREL, Offset);
}

void ThumbV7PILongThunk::addSymbols(ThunkSection &IS) {
  ThunkSym = addSyntheticLocal(
      Saver.save("__ThumbV7PILongThunk_" + Destination.getName()), STT_FUNC,
      Offset | 0x1, size(), IS);
  addSyntheticLocal("$t", STT_NOTYPE, Offset, 0, IS);
}

bool ThumbV7PILongThunk::isCompatibleWith(RelType Type) const {
  // ARM branch relocations can't use BLX
  return Type != R_ARM_JUMP24 && Type != R_ARM_PC24 && Type != R_ARM_PLT32;
}

// Write MIPS LA25 thunk code to call PIC function from the non-PIC one.
void MipsThunk::writeTo(uint8_t *Buf, ThunkSection &) const {
  uint64_t S = Destination.getVA();
  write32(Buf, 0x3c190000, Config->Endianness); // lui   $25, %hi(func)
  write32(Buf + 4, 0x08000000 | (S >> 2), Config->Endianness); // j     func
  write32(Buf + 8, 0x27390000, Config->Endianness); // addiu $25, $25, %lo(func)
  write32(Buf + 12, 0x00000000, Config->Endianness); // nop
  Target->relocateOne(Buf, R_MIPS_HI16, S);
  Target->relocateOne(Buf + 8, R_MIPS_LO16, S);
}

void MipsThunk::addSymbols(ThunkSection &IS) {
  ThunkSym =
      addSyntheticLocal(Saver.save("__LA25Thunk_" + Destination.getName()),
                        STT_FUNC, Offset, size(), IS);
}

InputSection *MipsThunk::getTargetInputSection() const {
  auto &DR = cast<Defined>(Destination);
  return dyn_cast<InputSection>(DR.Section);
}

// Write microMIPS R2-R5 LA25 thunk code
// to call PIC function from the non-PIC one.
void MicroMipsThunk::writeTo(uint8_t *Buf, ThunkSection &) const {
  uint64_t S = Destination.getVA() | 1;
  write16(Buf, 0x41b9, Config->Endianness);       // lui   $25, %hi(func)
  write16(Buf + 4, 0xd400, Config->Endianness);   // j     func
  write16(Buf + 8, 0x3339, Config->Endianness);   // addiu $25, $25, %lo(func)
  write16(Buf + 12, 0x0c00, Config->Endianness);  // nop
  Target->relocateOne(Buf, R_MICROMIPS_HI16, S);
  Target->relocateOne(Buf + 4, R_MICROMIPS_26_S1, S);
  Target->relocateOne(Buf + 8, R_MICROMIPS_LO16, S);
}

void MicroMipsThunk::addSymbols(ThunkSection &IS) {
  ThunkSym =
      addSyntheticLocal(Saver.save("__microLA25Thunk_" + Destination.getName()),
                        STT_FUNC, Offset, size(), IS);
  ThunkSym->StOther |= STO_MIPS_MICROMIPS;
}

InputSection *MicroMipsThunk::getTargetInputSection() const {
  auto &DR = cast<Defined>(Destination);
  return dyn_cast<InputSection>(DR.Section);
}

// Write microMIPS R6 LA25 thunk code
// to call PIC function from the non-PIC one.
void MicroMipsR6Thunk::writeTo(uint8_t *Buf, ThunkSection &) const {
  uint64_t S = Destination.getVA() | 1;
  uint64_t P = ThunkSym->getVA();
  write16(Buf, 0x1320, Config->Endianness);       // lui   $25, %hi(func)
  write16(Buf + 4, 0x3339, Config->Endianness);   // addiu $25, $25, %lo(func)
  write16(Buf + 8, 0x9400, Config->Endianness);   // bc    func
  Target->relocateOne(Buf, R_MICROMIPS_HI16, S);
  Target->relocateOne(Buf + 4, R_MICROMIPS_LO16, S);
  Target->relocateOne(Buf + 8, R_MICROMIPS_PC26_S1, S - P - 12);
}

void MicroMipsR6Thunk::addSymbols(ThunkSection &IS) {
  ThunkSym =
      addSyntheticLocal(Saver.save("__microLA25Thunk_" + Destination.getName()),
                        STT_FUNC, Offset, size(), IS);
  ThunkSym->StOther |= STO_MIPS_MICROMIPS;
}

InputSection *MicroMipsR6Thunk::getTargetInputSection() const {
  auto &DR = cast<Defined>(Destination);
  return dyn_cast<InputSection>(DR.Section);
}

Thunk::Thunk(Symbol &D) : Destination(D), Offset(0) {}

Thunk::~Thunk() = default;

static Thunk *addThunkAArch64(RelType Type, Symbol &S) {
  if (Type != R_AARCH64_CALL26 && Type != R_AARCH64_JUMP26)
    fatal("unrecognized relocation type");
  if (Config->Pic)
    return make<AArch64ADRPThunk>(S);
  return make<AArch64ABSLongThunk>(S);
}

// Creates a thunk for Thumb-ARM interworking.
static Thunk *addThunkArm(RelType Reloc, Symbol &S) {
  // ARM relocations need ARM to Thumb interworking Thunks.
  // Thumb relocations need Thumb to ARM relocations.
  // Use position independent Thunks if we require position independent code.
  switch (Reloc) {
  case R_ARM_PC24:
  case R_ARM_PLT32:
  case R_ARM_JUMP24:
  case R_ARM_CALL:
    if (Config->Pic)
      return make<ARMV7PILongThunk>(S);
    return make<ARMV7ABSLongThunk>(S);
  case R_ARM_THM_JUMP19:
  case R_ARM_THM_JUMP24:
  case R_ARM_THM_CALL:
    if (Config->Pic)
      return make<ThumbV7PILongThunk>(S);
    return make<ThumbV7ABSLongThunk>(S);
  }
  fatal("unrecognized relocation type");
}

static Thunk *addThunkMips(RelType Type, Symbol &S) {
  if ((S.StOther & STO_MIPS_MICROMIPS) && isMipsR6())
    return make<MicroMipsR6Thunk>(S);
  if (S.StOther & STO_MIPS_MICROMIPS)
    return make<MicroMipsThunk>(S);
  return make<MipsThunk>(S);
}

Thunk *addThunk(RelType Type, Symbol &S) {
  if (Config->EMachine == EM_AARCH64)
    return addThunkAArch64(Type, S);
  else if (Config->EMachine == EM_ARM)
    return addThunkArm(Type, S);
  else if (Config->EMachine == EM_MIPS)
    return addThunkMips(Type, S);
  llvm_unreachable("add Thunk only supported for ARM and Mips");
  return nullptr;
}

} // end namespace elf
} // end namespace lld
