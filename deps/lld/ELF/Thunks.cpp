//===- Thunks.cpp --------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
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
using namespace llvm::ELF;

namespace lld {
namespace elf {

namespace {

// AArch64 long range Thunks
class AArch64ABSLongThunk final : public Thunk {
public:
  AArch64ABSLongThunk(Symbol &dest) : Thunk(dest) {}
  uint32_t size() override { return 16; }
  void writeTo(uint8_t *buf) override;
  void addSymbols(ThunkSection &isec) override;
};

class AArch64ADRPThunk final : public Thunk {
public:
  AArch64ADRPThunk(Symbol &dest) : Thunk(dest) {}
  uint32_t size() override { return 12; }
  void writeTo(uint8_t *buf) override;
  void addSymbols(ThunkSection &isec) override;
};

// Base class for ARM thunks.
//
// An ARM thunk may be either short or long. A short thunk is simply a branch
// (B) instruction, and it may be used to call ARM functions when the distance
// from the thunk to the target is less than 32MB. Long thunks can branch to any
// virtual address and can switch between ARM and Thumb, and they are
// implemented in the derived classes. This class tries to create a short thunk
// if the target is in range, otherwise it creates a long thunk.
class ARMThunk : public Thunk {
public:
  ARMThunk(Symbol &dest) : Thunk(dest) {}

  bool getMayUseShortThunk();
  uint32_t size() override { return getMayUseShortThunk() ? 4 : sizeLong(); }
  void writeTo(uint8_t *buf) override;
  bool isCompatibleWith(const InputSection &isec,
                        const Relocation &rel) const override;

  // Returns the size of a long thunk.
  virtual uint32_t sizeLong() = 0;

  // Writes a long thunk to Buf.
  virtual void writeLong(uint8_t *buf) = 0;

private:
  // This field tracks whether all previously considered layouts would allow
  // this thunk to be short. If we have ever needed a long thunk, we always
  // create a long thunk, even if the thunk may be short given the current
  // distance to the target. We do this because transitioning from long to short
  // can create layout oscillations in certain corner cases which would prevent
  // the layout from converging.
  bool mayUseShortThunk = true;
};

// Base class for Thumb-2 thunks.
//
// This class is similar to ARMThunk, but it uses the Thumb-2 B.W instruction
// which has a range of 16MB.
class ThumbThunk : public Thunk {
public:
  ThumbThunk(Symbol &dest) : Thunk(dest) { alignment = 2; }

  bool getMayUseShortThunk();
  uint32_t size() override { return getMayUseShortThunk() ? 4 : sizeLong(); }
  void writeTo(uint8_t *buf) override;
  bool isCompatibleWith(const InputSection &isec,
                        const Relocation &rel) const override;

  // Returns the size of a long thunk.
  virtual uint32_t sizeLong() = 0;

  // Writes a long thunk to Buf.
  virtual void writeLong(uint8_t *buf) = 0;

private:
  // See comment in ARMThunk above.
  bool mayUseShortThunk = true;
};

// Specific ARM Thunk implementations. The naming convention is:
// Source State, TargetState, Target Requirement, ABS or PI, Range
class ARMV7ABSLongThunk final : public ARMThunk {
public:
  ARMV7ABSLongThunk(Symbol &dest) : ARMThunk(dest) {}

  uint32_t sizeLong() override { return 12; }
  void writeLong(uint8_t *buf) override;
  void addSymbols(ThunkSection &isec) override;
};

class ARMV7PILongThunk final : public ARMThunk {
public:
  ARMV7PILongThunk(Symbol &dest) : ARMThunk(dest) {}

  uint32_t sizeLong() override { return 16; }
  void writeLong(uint8_t *buf) override;
  void addSymbols(ThunkSection &isec) override;
};

class ThumbV7ABSLongThunk final : public ThumbThunk {
public:
  ThumbV7ABSLongThunk(Symbol &dest) : ThumbThunk(dest) {}

  uint32_t sizeLong() override { return 10; }
  void writeLong(uint8_t *buf) override;
  void addSymbols(ThunkSection &isec) override;
};

class ThumbV7PILongThunk final : public ThumbThunk {
public:
  ThumbV7PILongThunk(Symbol &dest) : ThumbThunk(dest) {}

  uint32_t sizeLong() override { return 12; }
  void writeLong(uint8_t *buf) override;
  void addSymbols(ThunkSection &isec) override;
};

// Implementations of Thunks for older Arm architectures that do not support
// the movt/movw instructions. These thunks require at least Architecture v5
// as used on processors such as the Arm926ej-s. There are no Thumb entry
// points as there is no Thumb branch instruction on these architecture that
// can result in a thunk
class ARMV5ABSLongThunk final : public ARMThunk {
public:
  ARMV5ABSLongThunk(Symbol &dest) : ARMThunk(dest) {}

  uint32_t sizeLong() override { return 8; }
  void writeLong(uint8_t *buf) override;
  void addSymbols(ThunkSection &isec) override;
  bool isCompatibleWith(const InputSection &isec,
                        const Relocation &rel) const override;
};

class ARMV5PILongThunk final : public ARMThunk {
public:
  ARMV5PILongThunk(Symbol &dest) : ARMThunk(dest) {}

  uint32_t sizeLong() override { return 16; }
  void writeLong(uint8_t *buf) override;
  void addSymbols(ThunkSection &isec) override;
  bool isCompatibleWith(const InputSection &isec,
                        const Relocation &rel) const override;
};

// Implementations of Thunks for Arm v6-M. Only Thumb instructions are permitted
class ThumbV6MABSLongThunk final : public ThumbThunk {
public:
  ThumbV6MABSLongThunk(Symbol &dest) : ThumbThunk(dest) {}

  uint32_t sizeLong() override { return 12; }
  void writeLong(uint8_t *buf) override;
  void addSymbols(ThunkSection &isec) override;
};

class ThumbV6MPILongThunk final : public ThumbThunk {
public:
  ThumbV6MPILongThunk(Symbol &dest) : ThumbThunk(dest) {}

  uint32_t sizeLong() override { return 16; }
  void writeLong(uint8_t *buf) override;
  void addSymbols(ThunkSection &isec) override;
};

// MIPS LA25 thunk
class MipsThunk final : public Thunk {
public:
  MipsThunk(Symbol &dest) : Thunk(dest) {}

  uint32_t size() override { return 16; }
  void writeTo(uint8_t *buf) override;
  void addSymbols(ThunkSection &isec) override;
  InputSection *getTargetInputSection() const override;
};

// microMIPS R2-R5 LA25 thunk
class MicroMipsThunk final : public Thunk {
public:
  MicroMipsThunk(Symbol &dest) : Thunk(dest) {}

  uint32_t size() override { return 14; }
  void writeTo(uint8_t *buf) override;
  void addSymbols(ThunkSection &isec) override;
  InputSection *getTargetInputSection() const override;
};

// microMIPS R6 LA25 thunk
class MicroMipsR6Thunk final : public Thunk {
public:
  MicroMipsR6Thunk(Symbol &dest) : Thunk(dest) {}

  uint32_t size() override { return 12; }
  void writeTo(uint8_t *buf) override;
  void addSymbols(ThunkSection &isec) override;
  InputSection *getTargetInputSection() const override;
};

class PPC32PltCallStub final : public Thunk {
public:
  PPC32PltCallStub(const InputSection &isec, const Relocation &rel, Symbol &dest)
      : Thunk(dest), addend(rel.type == R_PPC_PLTREL24 ? rel.addend : 0),
        file(isec.file) {}
  uint32_t size() override { return 16; }
  void writeTo(uint8_t *buf) override;
  void addSymbols(ThunkSection &isec) override;
  bool isCompatibleWith(const InputSection &isec, const Relocation &rel) const override;

private:
  // For R_PPC_PLTREL24, this records the addend, which will be used to decide
  // the offsets in the call stub.
  uint32_t addend;

  // Records the call site of the call stub.
  const InputFile *file;
};

// PPC64 Plt call stubs.
// Any call site that needs to call through a plt entry needs a call stub in
// the .text section. The call stub is responsible for:
// 1) Saving the toc-pointer to the stack.
// 2) Loading the target functions address from the procedure linkage table into
//    r12 for use by the target functions global entry point, and into the count
//    register.
// 3) Transfering control to the target function through an indirect branch.
class PPC64PltCallStub final : public Thunk {
public:
  PPC64PltCallStub(Symbol &dest) : Thunk(dest) {}
  uint32_t size() override { return 20; }
  void writeTo(uint8_t *buf) override;
  void addSymbols(ThunkSection &isec) override;
};

// A bl instruction uses a signed 24 bit offset, with an implicit 4 byte
// alignment. This gives a possible 26 bits of 'reach'. If the call offset is
// larger then that we need to emit a long-branch thunk. The target address
// of the callee is stored in a table to be accessed TOC-relative. Since the
// call must be local (a non-local call will have a PltCallStub instead) the
// table stores the address of the callee's local entry point. For
// position-independent code a corresponding relative dynamic relocation is
// used.
class PPC64LongBranchThunk : public Thunk {
public:
  uint32_t size() override { return 16; }
  void writeTo(uint8_t *buf) override;
  void addSymbols(ThunkSection &isec) override;

protected:
  PPC64LongBranchThunk(Symbol &dest) : Thunk(dest) {}
};

class PPC64PILongBranchThunk final : public PPC64LongBranchThunk {
public:
  PPC64PILongBranchThunk(Symbol &dest) : PPC64LongBranchThunk(dest) {
    assert(!dest.isPreemptible);
    if (dest.isInPPC64Branchlt())
      return;

    in.ppc64LongBranchTarget->addEntry(dest);
    mainPart->relaDyn->addReloc(
        {target->relativeRel, in.ppc64LongBranchTarget,
         dest.getPPC64LongBranchOffset(), true, &dest,
         getPPC64GlobalEntryToLocalEntryOffset(dest.stOther)});
  }
};

class PPC64PDLongBranchThunk final : public PPC64LongBranchThunk {
public:
  PPC64PDLongBranchThunk(Symbol &dest) : PPC64LongBranchThunk(dest) {
    if (!dest.isInPPC64Branchlt())
      in.ppc64LongBranchTarget->addEntry(dest);
  }
};

} // end anonymous namespace

Defined *Thunk::addSymbol(StringRef name, uint8_t type, uint64_t value,
                          InputSectionBase &section) {
  Defined *d = addSyntheticLocal(name, type, value, /*size=*/0, section);
  syms.push_back(d);
  return d;
}

void Thunk::setOffset(uint64_t newOffset) {
  for (Defined *d : syms)
    d->value = d->value - offset + newOffset;
  offset = newOffset;
}

// AArch64 long range Thunks

static uint64_t getAArch64ThunkDestVA(const Symbol &s) {
  uint64_t v = s.isInPlt() ? s.getPltVA() : s.getVA();
  return v;
}

void AArch64ABSLongThunk::writeTo(uint8_t *buf) {
  const uint8_t data[] = {
    0x50, 0x00, 0x00, 0x58, //     ldr x16, L0
    0x00, 0x02, 0x1f, 0xd6, //     br  x16
    0x00, 0x00, 0x00, 0x00, // L0: .xword S
    0x00, 0x00, 0x00, 0x00,
  };
  uint64_t s = getAArch64ThunkDestVA(destination);
  memcpy(buf, data, sizeof(data));
  target->relocateOne(buf + 8, R_AARCH64_ABS64, s);
}

void AArch64ABSLongThunk::addSymbols(ThunkSection &isec) {
  addSymbol(saver.save("__AArch64AbsLongThunk_" + destination.getName()),
            STT_FUNC, 0, isec);
  addSymbol("$x", STT_NOTYPE, 0, isec);
  addSymbol("$d", STT_NOTYPE, 8, isec);
}

// This Thunk has a maximum range of 4Gb, this is sufficient for all programs
// using the small code model, including pc-relative ones. At time of writing
// clang and gcc do not support the large code model for position independent
// code so it is safe to use this for position independent thunks without
// worrying about the destination being more than 4Gb away.
void AArch64ADRPThunk::writeTo(uint8_t *buf) {
  const uint8_t data[] = {
      0x10, 0x00, 0x00, 0x90, // adrp x16, Dest R_AARCH64_ADR_PREL_PG_HI21(Dest)
      0x10, 0x02, 0x00, 0x91, // add  x16, x16, R_AARCH64_ADD_ABS_LO12_NC(Dest)
      0x00, 0x02, 0x1f, 0xd6, // br   x16
  };
  uint64_t s = getAArch64ThunkDestVA(destination);
  uint64_t p = getThunkTargetSym()->getVA();
  memcpy(buf, data, sizeof(data));
  target->relocateOne(buf, R_AARCH64_ADR_PREL_PG_HI21,
                      getAArch64Page(s) - getAArch64Page(p));
  target->relocateOne(buf + 4, R_AARCH64_ADD_ABS_LO12_NC, s);
}

void AArch64ADRPThunk::addSymbols(ThunkSection &isec) {
  addSymbol(saver.save("__AArch64ADRPThunk_" + destination.getName()), STT_FUNC,
            0, isec);
  addSymbol("$x", STT_NOTYPE, 0, isec);
}

// ARM Target Thunks
static uint64_t getARMThunkDestVA(const Symbol &s) {
  uint64_t v = s.isInPlt() ? s.getPltVA() : s.getVA();
  return SignExtend64<32>(v);
}

// This function returns true if the target is not Thumb and is within 2^26, and
// it has not previously returned false (see comment for mayUseShortThunk).
bool ARMThunk::getMayUseShortThunk() {
  if (!mayUseShortThunk)
    return false;
  uint64_t s = getARMThunkDestVA(destination);
  if (s & 1) {
    mayUseShortThunk = false;
    return false;
  }
  uint64_t p = getThunkTargetSym()->getVA();
  int64_t offset = s - p - 8;
  mayUseShortThunk = llvm::isInt<26>(offset);
  return mayUseShortThunk;
}

void ARMThunk::writeTo(uint8_t *buf) {
  if (!getMayUseShortThunk()) {
    writeLong(buf);
    return;
  }

  uint64_t s = getARMThunkDestVA(destination);
  uint64_t p = getThunkTargetSym()->getVA();
  int64_t offset = s - p - 8;
  const uint8_t data[] = {
    0x00, 0x00, 0x00, 0xea, // b S
  };
  memcpy(buf, data, sizeof(data));
  target->relocateOne(buf, R_ARM_JUMP24, offset);
}

bool ARMThunk::isCompatibleWith(const InputSection &isec,
                                const Relocation &rel) const {
  // Thumb branch relocations can't use BLX
  return rel.type != R_ARM_THM_JUMP19 && rel.type != R_ARM_THM_JUMP24;
}

// This function returns true if the target is Thumb and is within 2^25, and
// it has not previously returned false (see comment for mayUseShortThunk).
bool ThumbThunk::getMayUseShortThunk() {
  if (!mayUseShortThunk)
    return false;
  uint64_t s = getARMThunkDestVA(destination);
  if ((s & 1) == 0) {
    mayUseShortThunk = false;
    return false;
  }
  uint64_t p = getThunkTargetSym()->getVA() & ~1;
  int64_t offset = s - p - 4;
  mayUseShortThunk = llvm::isInt<25>(offset);
  return mayUseShortThunk;
}

void ThumbThunk::writeTo(uint8_t *buf) {
  if (!getMayUseShortThunk()) {
    writeLong(buf);
    return;
  }

  uint64_t s = getARMThunkDestVA(destination);
  uint64_t p = getThunkTargetSym()->getVA();
  int64_t offset = s - p - 4;
  const uint8_t data[] = {
      0x00, 0xf0, 0x00, 0xb0, // b.w S
  };
  memcpy(buf, data, sizeof(data));
  target->relocateOne(buf, R_ARM_THM_JUMP24, offset);
}

bool ThumbThunk::isCompatibleWith(const InputSection &isec,
                                  const Relocation &rel) const {
  // ARM branch relocations can't use BLX
  return rel.type != R_ARM_JUMP24 && rel.type != R_ARM_PC24 && rel.type != R_ARM_PLT32;
}

void ARMV7ABSLongThunk::writeLong(uint8_t *buf) {
  const uint8_t data[] = {
      0x00, 0xc0, 0x00, 0xe3, // movw         ip,:lower16:S
      0x00, 0xc0, 0x40, 0xe3, // movt         ip,:upper16:S
      0x1c, 0xff, 0x2f, 0xe1, // bx   ip
  };
  uint64_t s = getARMThunkDestVA(destination);
  memcpy(buf, data, sizeof(data));
  target->relocateOne(buf, R_ARM_MOVW_ABS_NC, s);
  target->relocateOne(buf + 4, R_ARM_MOVT_ABS, s);
}

void ARMV7ABSLongThunk::addSymbols(ThunkSection &isec) {
  addSymbol(saver.save("__ARMv7ABSLongThunk_" + destination.getName()),
            STT_FUNC, 0, isec);
  addSymbol("$a", STT_NOTYPE, 0, isec);
}

void ThumbV7ABSLongThunk::writeLong(uint8_t *buf) {
  const uint8_t data[] = {
      0x40, 0xf2, 0x00, 0x0c, // movw         ip, :lower16:S
      0xc0, 0xf2, 0x00, 0x0c, // movt         ip, :upper16:S
      0x60, 0x47,             // bx   ip
  };
  uint64_t s = getARMThunkDestVA(destination);
  memcpy(buf, data, sizeof(data));
  target->relocateOne(buf, R_ARM_THM_MOVW_ABS_NC, s);
  target->relocateOne(buf + 4, R_ARM_THM_MOVT_ABS, s);
}

void ThumbV7ABSLongThunk::addSymbols(ThunkSection &isec) {
  addSymbol(saver.save("__Thumbv7ABSLongThunk_" + destination.getName()),
            STT_FUNC, 1, isec);
  addSymbol("$t", STT_NOTYPE, 0, isec);
}

void ARMV7PILongThunk::writeLong(uint8_t *buf) {
  const uint8_t data[] = {
      0xf0, 0xcf, 0x0f, 0xe3, // P:  movw ip,:lower16:S - (P + (L1-P) + 8)
      0x00, 0xc0, 0x40, 0xe3, //     movt ip,:upper16:S - (P + (L1-P) + 8)
      0x0f, 0xc0, 0x8c, 0xe0, // L1: add  ip, ip, pc
      0x1c, 0xff, 0x2f, 0xe1, //     bx   ip
  };
  uint64_t s = getARMThunkDestVA(destination);
  uint64_t p = getThunkTargetSym()->getVA();
  int64_t offset = s - p - 16;
  memcpy(buf, data, sizeof(data));
  target->relocateOne(buf, R_ARM_MOVW_PREL_NC, offset);
  target->relocateOne(buf + 4, R_ARM_MOVT_PREL, offset);
}

void ARMV7PILongThunk::addSymbols(ThunkSection &isec) {
  addSymbol(saver.save("__ARMV7PILongThunk_" + destination.getName()), STT_FUNC,
            0, isec);
  addSymbol("$a", STT_NOTYPE, 0, isec);
}

void ThumbV7PILongThunk::writeLong(uint8_t *buf) {
  const uint8_t data[] = {
      0x4f, 0xf6, 0xf4, 0x7c, // P:  movw ip,:lower16:S - (P + (L1-P) + 4)
      0xc0, 0xf2, 0x00, 0x0c, //     movt ip,:upper16:S - (P + (L1-P) + 4)
      0xfc, 0x44,             // L1: add  ip, pc
      0x60, 0x47,             //     bx   ip
  };
  uint64_t s = getARMThunkDestVA(destination);
  uint64_t p = getThunkTargetSym()->getVA() & ~0x1;
  int64_t offset = s - p - 12;
  memcpy(buf, data, sizeof(data));
  target->relocateOne(buf, R_ARM_THM_MOVW_PREL_NC, offset);
  target->relocateOne(buf + 4, R_ARM_THM_MOVT_PREL, offset);
}

void ThumbV7PILongThunk::addSymbols(ThunkSection &isec) {
  addSymbol(saver.save("__ThumbV7PILongThunk_" + destination.getName()),
            STT_FUNC, 1, isec);
  addSymbol("$t", STT_NOTYPE, 0, isec);
}

void ARMV5ABSLongThunk::writeLong(uint8_t *buf) {
  const uint8_t data[] = {
      0x04, 0xf0, 0x1f, 0xe5, //     ldr pc, [pc,#-4] ; L1
      0x00, 0x00, 0x00, 0x00, // L1: .word S
  };
  memcpy(buf, data, sizeof(data));
  target->relocateOne(buf + 4, R_ARM_ABS32, getARMThunkDestVA(destination));
}

void ARMV5ABSLongThunk::addSymbols(ThunkSection &isec) {
  addSymbol(saver.save("__ARMv5ABSLongThunk_" + destination.getName()),
            STT_FUNC, 0, isec);
  addSymbol("$a", STT_NOTYPE, 0, isec);
  addSymbol("$d", STT_NOTYPE, 4, isec);
}

bool ARMV5ABSLongThunk::isCompatibleWith(const InputSection &isec,
                                         const Relocation &rel) const {
  // Thumb branch relocations can't use BLX
  return rel.type != R_ARM_THM_JUMP19 && rel.type != R_ARM_THM_JUMP24;
}

void ARMV5PILongThunk::writeLong(uint8_t *buf) {
  const uint8_t data[] = {
      0x04, 0xc0, 0x9f, 0xe5, // P:  ldr ip, [pc,#4] ; L2
      0x0c, 0xc0, 0x8f, 0xe0, // L1: add ip, pc, ip
      0x1c, 0xff, 0x2f, 0xe1, //     bx ip
      0x00, 0x00, 0x00, 0x00, // L2: .word S - (P + (L1 - P) + 8)
  };
  uint64_t s = getARMThunkDestVA(destination);
  uint64_t p = getThunkTargetSym()->getVA() & ~0x1;
  memcpy(buf, data, sizeof(data));
  target->relocateOne(buf + 12, R_ARM_REL32, s - p - 12);
}

void ARMV5PILongThunk::addSymbols(ThunkSection &isec) {
  addSymbol(saver.save("__ARMV5PILongThunk_" + destination.getName()), STT_FUNC,
            0, isec);
  addSymbol("$a", STT_NOTYPE, 0, isec);
  addSymbol("$d", STT_NOTYPE, 12, isec);
}

bool ARMV5PILongThunk::isCompatibleWith(const InputSection &isec,
                                        const Relocation &rel) const {
  // Thumb branch relocations can't use BLX
  return rel.type != R_ARM_THM_JUMP19 && rel.type != R_ARM_THM_JUMP24;
}

void ThumbV6MABSLongThunk::writeLong(uint8_t *buf) {
  // Most Thumb instructions cannot access the high registers r8 - r15. As the
  // only register we can corrupt is r12 we must instead spill a low register
  // to the stack to use as a scratch register. We push r1 even though we
  // don't need to get some space to use for the return address.
  const uint8_t data[] = {
      0x03, 0xb4,            // push {r0, r1} ; Obtain scratch registers
      0x01, 0x48,            // ldr r0, [pc, #4] ; L1
      0x01, 0x90,            // str r0, [sp, #4] ; SP + 4 = S
      0x01, 0xbd,            // pop {r0, pc} ; restore r0 and branch to dest
      0x00, 0x00, 0x00, 0x00 // L1: .word S
  };
  uint64_t s = getARMThunkDestVA(destination);
  memcpy(buf, data, sizeof(data));
  target->relocateOne(buf + 8, R_ARM_ABS32, s);
}

void ThumbV6MABSLongThunk::addSymbols(ThunkSection &isec) {
  addSymbol(saver.save("__Thumbv6MABSLongThunk_" + destination.getName()),
            STT_FUNC, 1, isec);
  addSymbol("$t", STT_NOTYPE, 0, isec);
  addSymbol("$d", STT_NOTYPE, 8, isec);
}

void ThumbV6MPILongThunk::writeLong(uint8_t *buf) {
  // Most Thumb instructions cannot access the high registers r8 - r15. As the
  // only register we can corrupt is ip (r12) we must instead spill a low
  // register to the stack to use as a scratch register.
  const uint8_t data[] = {
      0x01, 0xb4,             // P:  push {r0}        ; Obtain scratch register
      0x02, 0x48,             //     ldr r0, [pc, #8] ; L2
      0x84, 0x46,             //     mov ip, r0       ; high to low register
      0x01, 0xbc,             //     pop {r0}         ; restore scratch register
      0xe7, 0x44,             // L1: add pc, ip       ; transfer control
      0xc0, 0x46,             //     nop              ; pad to 4-byte boundary
      0x00, 0x00, 0x00, 0x00, // L2: .word S - (P + (L1 - P) + 4)
  };
  uint64_t s = getARMThunkDestVA(destination);
  uint64_t p = getThunkTargetSym()->getVA() & ~0x1;
  memcpy(buf, data, sizeof(data));
  target->relocateOne(buf + 12, R_ARM_REL32, s - p - 12);
}

void ThumbV6MPILongThunk::addSymbols(ThunkSection &isec) {
  addSymbol(saver.save("__Thumbv6MPILongThunk_" + destination.getName()),
            STT_FUNC, 1, isec);
  addSymbol("$t", STT_NOTYPE, 0, isec);
  addSymbol("$d", STT_NOTYPE, 12, isec);
}

// Write MIPS LA25 thunk code to call PIC function from the non-PIC one.
void MipsThunk::writeTo(uint8_t *buf) {
  uint64_t s = destination.getVA();
  write32(buf, 0x3c190000); // lui   $25, %hi(func)
  write32(buf + 4, 0x08000000 | (s >> 2)); // j     func
  write32(buf + 8, 0x27390000); // addiu $25, $25, %lo(func)
  write32(buf + 12, 0x00000000); // nop
  target->relocateOne(buf, R_MIPS_HI16, s);
  target->relocateOne(buf + 8, R_MIPS_LO16, s);
}

void MipsThunk::addSymbols(ThunkSection &isec) {
  addSymbol(saver.save("__LA25Thunk_" + destination.getName()), STT_FUNC, 0,
            isec);
}

InputSection *MipsThunk::getTargetInputSection() const {
  auto &dr = cast<Defined>(destination);
  return dyn_cast<InputSection>(dr.section);
}

// Write microMIPS R2-R5 LA25 thunk code
// to call PIC function from the non-PIC one.
void MicroMipsThunk::writeTo(uint8_t *buf) {
  uint64_t s = destination.getVA();
  write16(buf, 0x41b9);       // lui   $25, %hi(func)
  write16(buf + 4, 0xd400);   // j     func
  write16(buf + 8, 0x3339);   // addiu $25, $25, %lo(func)
  write16(buf + 12, 0x0c00);  // nop
  target->relocateOne(buf, R_MICROMIPS_HI16, s);
  target->relocateOne(buf + 4, R_MICROMIPS_26_S1, s);
  target->relocateOne(buf + 8, R_MICROMIPS_LO16, s);
}

void MicroMipsThunk::addSymbols(ThunkSection &isec) {
  Defined *d = addSymbol(
      saver.save("__microLA25Thunk_" + destination.getName()), STT_FUNC, 0, isec);
  d->stOther |= STO_MIPS_MICROMIPS;
}

InputSection *MicroMipsThunk::getTargetInputSection() const {
  auto &dr = cast<Defined>(destination);
  return dyn_cast<InputSection>(dr.section);
}

// Write microMIPS R6 LA25 thunk code
// to call PIC function from the non-PIC one.
void MicroMipsR6Thunk::writeTo(uint8_t *buf) {
  uint64_t s = destination.getVA();
  uint64_t p = getThunkTargetSym()->getVA();
  write16(buf, 0x1320);       // lui   $25, %hi(func)
  write16(buf + 4, 0x3339);   // addiu $25, $25, %lo(func)
  write16(buf + 8, 0x9400);   // bc    func
  target->relocateOne(buf, R_MICROMIPS_HI16, s);
  target->relocateOne(buf + 4, R_MICROMIPS_LO16, s);
  target->relocateOne(buf + 8, R_MICROMIPS_PC26_S1, s - p - 12);
}

void MicroMipsR6Thunk::addSymbols(ThunkSection &isec) {
  Defined *d = addSymbol(
      saver.save("__microLA25Thunk_" + destination.getName()), STT_FUNC, 0, isec);
  d->stOther |= STO_MIPS_MICROMIPS;
}

InputSection *MicroMipsR6Thunk::getTargetInputSection() const {
  auto &dr = cast<Defined>(destination);
  return dyn_cast<InputSection>(dr.section);
}

void PPC32PltCallStub::writeTo(uint8_t *buf) {
  if (!config->isPic) {
    uint64_t va = destination.getGotPltVA();
    write32(buf + 0, 0x3d600000 | (va + 0x8000) >> 16); // lis r11,ha
    write32(buf + 4, 0x816b0000 | (uint16_t)va);        // lwz r11,l(r11)
    write32(buf + 8, 0x7d6903a6);                       // mtctr r11
    write32(buf + 12, 0x4e800420);                      // bctr
    return;
  }
  uint32_t offset;
  if (addend >= 0x8000) {
    // The stub loads an address relative to r30 (.got2+Addend). Addend is
    // almost always 0x8000. The address of .got2 is different in another object
    // file, so a stub cannot be shared.
    offset = destination.getGotPltVA() - (in.ppc32Got2->getParent()->getVA() +
                                          file->ppc32Got2OutSecOff + addend);
  } else {
    // The stub loads an address relative to _GLOBAL_OFFSET_TABLE_ (which is
    // currently the address of .got).
    offset = destination.getGotPltVA() - in.got->getVA();
  }
  uint16_t ha = (offset + 0x8000) >> 16, l = (uint16_t)offset;
  if (ha == 0) {
    write32(buf + 0, 0x817e0000 | l); // lwz r11,l(r30)
    write32(buf + 4, 0x7d6903a6);     // mtctr r11
    write32(buf + 8, 0x4e800420);     // bctr
    write32(buf + 12, 0x60000000);    // nop
  } else {
    write32(buf + 0, 0x3d7e0000 | ha); // addis r11,r30,ha
    write32(buf + 4, 0x816b0000 | l);  // lwz r11,l(r11)
    write32(buf + 8, 0x7d6903a6);      // mtctr r11
    write32(buf + 12, 0x4e800420);     // bctr
  }
}

void PPC32PltCallStub::addSymbols(ThunkSection &isec) {
  std::string buf;
  raw_string_ostream os(buf);
  os << format_hex_no_prefix(addend, 8);
  if (!config->isPic)
    os << ".plt_call32.";
  else if (addend >= 0x8000)
    os << ".got2.plt_pic32.";
  else
    os << ".plt_pic32.";
  os << destination.getName();
  addSymbol(saver.save(os.str()), STT_FUNC, 0, isec);
}

bool PPC32PltCallStub::isCompatibleWith(const InputSection &isec,
                                        const Relocation &rel) const {
  return !config->isPic || (isec.file == file && rel.addend == addend);
}

static void writePPCLoadAndBranch(uint8_t *buf, int64_t offset) {
  uint16_t offHa = (offset + 0x8000) >> 16;
  uint16_t offLo = offset & 0xffff;

  write32(buf + 0, 0x3d820000 | offHa); // addis r12, r2, OffHa
  write32(buf + 4, 0xe98c0000 | offLo); // ld    r12, OffLo(r12)
  write32(buf + 8, 0x7d8903a6);         // mtctr r12
  write32(buf + 12, 0x4e800420);        // bctr
}

void PPC64PltCallStub::writeTo(uint8_t *buf) {
  int64_t offset = destination.getGotPltVA() - getPPC64TocBase();
  // Save the TOC pointer to the save-slot reserved in the call frame.
  write32(buf + 0, 0xf8410018); // std     r2,24(r1)
  writePPCLoadAndBranch(buf + 4, offset);
}

void PPC64PltCallStub::addSymbols(ThunkSection &isec) {
  Defined *s = addSymbol(saver.save("__plt_" + destination.getName()), STT_FUNC,
                         0, isec);
  s->needsTocRestore = true;
}

void PPC64LongBranchThunk::writeTo(uint8_t *buf) {
  int64_t offset = destination.getPPC64LongBranchTableVA() - getPPC64TocBase();
  writePPCLoadAndBranch(buf, offset);
}

void PPC64LongBranchThunk::addSymbols(ThunkSection &isec) {
  addSymbol(saver.save("__long_branch_" + destination.getName()), STT_FUNC, 0,
            isec);
}

Thunk::Thunk(Symbol &d) : destination(d), offset(0) {}

Thunk::~Thunk() = default;

static Thunk *addThunkAArch64(RelType type, Symbol &s) {
  if (type != R_AARCH64_CALL26 && type != R_AARCH64_JUMP26)
    fatal("unrecognized relocation type");
  if (config->picThunk)
    return make<AArch64ADRPThunk>(s);
  return make<AArch64ABSLongThunk>(s);
}

// Creates a thunk for Thumb-ARM interworking.
// Arm Architectures v5 and v6 do not support Thumb2 technology. This means
// - MOVT and MOVW instructions cannot be used
// - Only Thumb relocation that can generate a Thunk is a BL, this can always
//   be transformed into a BLX
static Thunk *addThunkPreArmv7(RelType reloc, Symbol &s) {
  switch (reloc) {
  case R_ARM_PC24:
  case R_ARM_PLT32:
  case R_ARM_JUMP24:
  case R_ARM_CALL:
  case R_ARM_THM_CALL:
    if (config->picThunk)
      return make<ARMV5PILongThunk>(s);
    return make<ARMV5ABSLongThunk>(s);
  }
  fatal("relocation " + toString(reloc) + " to " + toString(s) +
        " not supported for Armv5 or Armv6 targets");
}

// Create a thunk for Thumb long branch on V6-M.
// Arm Architecture v6-M only supports Thumb instructions. This means
// - MOVT and MOVW instructions cannot be used.
// - Only a limited number of instructions can access registers r8 and above
// - No interworking support is needed (all Thumb).
static Thunk *addThunkV6M(RelType reloc, Symbol &s) {
  switch (reloc) {
  case R_ARM_THM_JUMP19:
  case R_ARM_THM_JUMP24:
  case R_ARM_THM_CALL:
    if (config->isPic)
      return make<ThumbV6MPILongThunk>(s);
    return make<ThumbV6MABSLongThunk>(s);
  }
  fatal("relocation " + toString(reloc) + " to " + toString(s) +
        " not supported for Armv6-M targets");
}

// Creates a thunk for Thumb-ARM interworking or branch range extension.
static Thunk *addThunkArm(RelType reloc, Symbol &s) {
  // Decide which Thunk is needed based on:
  // Available instruction set
  // - An Arm Thunk can only be used if Arm state is available.
  // - A Thumb Thunk can only be used if Thumb state is available.
  // - Can only use a Thunk if it uses instructions that the Target supports.
  // Relocation is branch or branch and link
  // - Branch instructions cannot change state, can only select Thunk that
  //   starts in the same state as the caller.
  // - Branch and link relocations can change state, can select Thunks from
  //   either Arm or Thumb.
  // Position independent Thunks if we require position independent code.

  // Handle architectures that have restrictions on the instructions that they
  // can use in Thunks. The flags below are set by reading the BuildAttributes
  // of the input objects. InputFiles.cpp contains the mapping from ARM
  // architecture to flag.
  if (!config->armHasMovtMovw) {
    if (!config->armJ1J2BranchEncoding)
      return addThunkPreArmv7(reloc, s);
    return addThunkV6M(reloc, s);
  }

  switch (reloc) {
  case R_ARM_PC24:
  case R_ARM_PLT32:
  case R_ARM_JUMP24:
  case R_ARM_CALL:
    if (config->picThunk)
      return make<ARMV7PILongThunk>(s);
    return make<ARMV7ABSLongThunk>(s);
  case R_ARM_THM_JUMP19:
  case R_ARM_THM_JUMP24:
  case R_ARM_THM_CALL:
    if (config->picThunk)
      return make<ThumbV7PILongThunk>(s);
    return make<ThumbV7ABSLongThunk>(s);
  }
  fatal("unrecognized relocation type");
}

static Thunk *addThunkMips(RelType type, Symbol &s) {
  if ((s.stOther & STO_MIPS_MICROMIPS) && isMipsR6())
    return make<MicroMipsR6Thunk>(s);
  if (s.stOther & STO_MIPS_MICROMIPS)
    return make<MicroMipsThunk>(s);
  return make<MipsThunk>(s);
}

static Thunk *addThunkPPC32(const InputSection &isec, const Relocation &rel, Symbol &s) {
  assert((rel.type == R_PPC_REL24 || rel.type == R_PPC_PLTREL24) &&
         "unexpected relocation type for thunk");
  return make<PPC32PltCallStub>(isec, rel, s);
}

static Thunk *addThunkPPC64(RelType type, Symbol &s) {
  assert(type == R_PPC64_REL24 && "unexpected relocation type for thunk");
  if (s.isInPlt())
    return make<PPC64PltCallStub>(s);

  if (config->picThunk)
    return make<PPC64PILongBranchThunk>(s);

  return make<PPC64PDLongBranchThunk>(s);
}

Thunk *addThunk(const InputSection &isec, Relocation &rel) {
  Symbol &s = *rel.sym;

  if (config->emachine == EM_AARCH64)
    return addThunkAArch64(rel.type, s);

  if (config->emachine == EM_ARM)
    return addThunkArm(rel.type, s);

  if (config->emachine == EM_MIPS)
    return addThunkMips(rel.type, s);

  if (config->emachine == EM_PPC)
    return addThunkPPC32(isec, rel, s);

  if (config->emachine == EM_PPC64)
    return addThunkPPC64(rel.type, s);

  llvm_unreachable("add Thunk only supported for ARM, Mips and PowerPC");
}

} // end namespace elf
} // end namespace lld
