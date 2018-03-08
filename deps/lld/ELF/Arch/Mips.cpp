//===- MIPS.cpp -----------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "InputFiles.h"
#include "OutputSections.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "Thunks.h"
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
template <class ELFT> class MIPS final : public TargetInfo {
public:
  MIPS();
  uint32_t calcEFlags() const override;
  RelExpr getRelExpr(RelType Type, const Symbol &S,
                     const uint8_t *Loc) const override;
  int64_t getImplicitAddend(const uint8_t *Buf, RelType Type) const override;
  bool isPicRel(RelType Type) const override;
  RelType getDynRel(RelType Type) const override;
  void writeGotPlt(uint8_t *Buf, const Symbol &S) const override;
  void writePltHeader(uint8_t *Buf) const override;
  void writePlt(uint8_t *Buf, uint64_t GotPltEntryAddr, uint64_t PltEntryAddr,
                int32_t Index, unsigned RelOff) const override;
  bool needsThunk(RelExpr Expr, RelType Type, const InputFile *File,
                  uint64_t BranchAddr, const Symbol &S) const override;
  void relocateOne(uint8_t *Loc, RelType Type, uint64_t Val) const override;
  bool usesOnlyLowPageBits(RelType Type) const override;
};
} // namespace

template <class ELFT> MIPS<ELFT>::MIPS() {
  GotPltHeaderEntriesNum = 2;
  DefaultMaxPageSize = 65536;
  GotEntrySize = sizeof(typename ELFT::uint);
  GotPltEntrySize = sizeof(typename ELFT::uint);
  PltEntrySize = 16;
  PltHeaderSize = 32;
  CopyRel = R_MIPS_COPY;
  PltRel = R_MIPS_JUMP_SLOT;
  NeedsThunks = true;
  TrapInstr = 0xefefefef;

  if (ELFT::Is64Bits) {
    RelativeRel = (R_MIPS_64 << 8) | R_MIPS_REL32;
    TlsGotRel = R_MIPS_TLS_TPREL64;
    TlsModuleIndexRel = R_MIPS_TLS_DTPMOD64;
    TlsOffsetRel = R_MIPS_TLS_DTPREL64;
  } else {
    RelativeRel = R_MIPS_REL32;
    TlsGotRel = R_MIPS_TLS_TPREL32;
    TlsModuleIndexRel = R_MIPS_TLS_DTPMOD32;
    TlsOffsetRel = R_MIPS_TLS_DTPREL32;
  }
}

template <class ELFT> uint32_t MIPS<ELFT>::calcEFlags() const {
  return calcMipsEFlags<ELFT>();
}

template <class ELFT>
RelExpr MIPS<ELFT>::getRelExpr(RelType Type, const Symbol &S,
                               const uint8_t *Loc) const {
  // See comment in the calculateMipsRelChain.
  if (ELFT::Is64Bits || Config->MipsN32Abi)
    Type &= 0xff;

  switch (Type) {
  case R_MIPS_JALR:
  case R_MICROMIPS_JALR:
    return R_HINT;
  case R_MIPS_GPREL16:
  case R_MIPS_GPREL32:
  case R_MICROMIPS_GPREL16:
  case R_MICROMIPS_GPREL7_S2:
    return R_MIPS_GOTREL;
  case R_MIPS_26:
  case R_MICROMIPS_26_S1:
    return R_PLT;
  case R_MICROMIPS_PC26_S1:
    return R_PLT_PC;
  case R_MIPS_HI16:
  case R_MIPS_LO16:
  case R_MIPS_HIGHER:
  case R_MIPS_HIGHEST:
  case R_MICROMIPS_HI16:
  case R_MICROMIPS_LO16:
  case R_MICROMIPS_HIGHER:
  case R_MICROMIPS_HIGHEST:
    // R_MIPS_HI16/R_MIPS_LO16 relocations against _gp_disp calculate
    // offset between start of function and 'gp' value which by default
    // equal to the start of .got section. In that case we consider these
    // relocations as relative.
    if (&S == ElfSym::MipsGpDisp)
      return R_MIPS_GOT_GP_PC;
    if (&S == ElfSym::MipsLocalGp)
      return R_MIPS_GOT_GP;
    LLVM_FALLTHROUGH;
  case R_MIPS_32:
  case R_MIPS_64:
  case R_MIPS_GOT_OFST:
  case R_MIPS_SUB:
  case R_MIPS_TLS_DTPREL_HI16:
  case R_MIPS_TLS_DTPREL_LO16:
  case R_MIPS_TLS_DTPREL32:
  case R_MIPS_TLS_DTPREL64:
  case R_MIPS_TLS_TPREL_HI16:
  case R_MIPS_TLS_TPREL_LO16:
  case R_MIPS_TLS_TPREL32:
  case R_MIPS_TLS_TPREL64:
  case R_MICROMIPS_GOT_OFST:
  case R_MICROMIPS_SUB:
  case R_MICROMIPS_TLS_DTPREL_HI16:
  case R_MICROMIPS_TLS_DTPREL_LO16:
  case R_MICROMIPS_TLS_TPREL_HI16:
  case R_MICROMIPS_TLS_TPREL_LO16:
    return R_ABS;
  case R_MIPS_PC32:
  case R_MIPS_PC16:
  case R_MIPS_PC19_S2:
  case R_MIPS_PC21_S2:
  case R_MIPS_PC26_S2:
  case R_MIPS_PCHI16:
  case R_MIPS_PCLO16:
  case R_MICROMIPS_PC7_S1:
  case R_MICROMIPS_PC10_S1:
  case R_MICROMIPS_PC16_S1:
  case R_MICROMIPS_PC18_S3:
  case R_MICROMIPS_PC19_S2:
  case R_MICROMIPS_PC23_S2:
  case R_MICROMIPS_PC21_S1:
    return R_PC;
  case R_MIPS_GOT16:
  case R_MICROMIPS_GOT16:
    if (S.isLocal())
      return R_MIPS_GOT_LOCAL_PAGE;
    LLVM_FALLTHROUGH;
  case R_MIPS_CALL16:
  case R_MIPS_GOT_DISP:
  case R_MIPS_TLS_GOTTPREL:
  case R_MICROMIPS_CALL16:
  case R_MICROMIPS_GOT_DISP:
  case R_MICROMIPS_TLS_GOTTPREL:
    return R_MIPS_GOT_OFF;
  case R_MIPS_CALL_HI16:
  case R_MIPS_CALL_LO16:
  case R_MIPS_GOT_HI16:
  case R_MIPS_GOT_LO16:
  case R_MICROMIPS_CALL_HI16:
  case R_MICROMIPS_CALL_LO16:
  case R_MICROMIPS_GOT_HI16:
  case R_MICROMIPS_GOT_LO16:
    return R_MIPS_GOT_OFF32;
  case R_MIPS_GOT_PAGE:
  case R_MICROMIPS_GOT_PAGE:
    return R_MIPS_GOT_LOCAL_PAGE;
  case R_MIPS_TLS_GD:
  case R_MICROMIPS_TLS_GD:
    return R_MIPS_TLSGD;
  case R_MIPS_TLS_LDM:
  case R_MICROMIPS_TLS_LDM:
    return R_MIPS_TLSLD;
  case R_MIPS_NONE:
    return R_NONE;
  default:
    return R_INVALID;
  }
}

template <class ELFT> bool MIPS<ELFT>::isPicRel(RelType Type) const {
  return Type == R_MIPS_32 || Type == R_MIPS_64;
}

template <class ELFT> RelType MIPS<ELFT>::getDynRel(RelType Type) const {
  return RelativeRel;
}

template <class ELFT>
void MIPS<ELFT>::writeGotPlt(uint8_t *Buf, const Symbol &) const {
  uint64_t VA = InX::Plt->getVA();
  if (isMicroMips())
    VA |= 1;
  write32<ELFT::TargetEndianness>(Buf, VA);
}

template <endianness E> static uint32_t readShuffle(const uint8_t *Loc) {
  // The major opcode of a microMIPS instruction needs to appear
  // in the first 16-bit word (lowest address) for efficient hardware
  // decode so that it knows if the instruction is 16-bit or 32-bit
  // as early as possible. To do so, little-endian binaries keep 16-bit
  // words in a big-endian order. That is why we have to swap these
  // words to get a correct value.
  uint32_t V = read32<E>(Loc);
  if (E == support::little)
    return (V << 16) | (V >> 16);
  return V;
}

template <endianness E>
static void writeRelocation(uint8_t *Loc, uint64_t V, uint8_t BitsSize,
                            uint8_t Shift) {
  uint32_t Instr = read32<E>(Loc);
  uint32_t Mask = 0xffffffff >> (32 - BitsSize);
  uint32_t Data = (Instr & ~Mask) | ((V >> Shift) & Mask);
  write32<E>(Loc, Data);
}

template <endianness E>
static void writeMicroRelocation32(uint8_t *Loc, uint64_t V, uint8_t BitsSize,
                                   uint8_t Shift) {
  // See comments in readShuffle for purpose of this code.
  uint16_t *Words = (uint16_t *)Loc;
  if (E == support::little)
    std::swap(Words[0], Words[1]);

  writeRelocation<E>(Loc, V, BitsSize, Shift);

  if (E == support::little)
    std::swap(Words[0], Words[1]);
}

template <endianness E>
static void writeMicroRelocation16(uint8_t *Loc, uint64_t V, uint8_t BitsSize,
                                   uint8_t Shift) {
  uint16_t Instr = read16<E>(Loc);
  uint16_t Mask = 0xffff >> (16 - BitsSize);
  uint16_t Data = (Instr & ~Mask) | ((V >> Shift) & Mask);
  write16<E>(Loc, Data);
}

template <class ELFT> void MIPS<ELFT>::writePltHeader(uint8_t *Buf) const {
  const endianness E = ELFT::TargetEndianness;
  if (isMicroMips()) {
    uint64_t GotPlt = InX::GotPlt->getVA();
    uint64_t Plt = InX::Plt->getVA();
    // Overwrite trap instructions written by Writer::writeTrapInstr.
    memset(Buf, 0, PltHeaderSize);

    write16<E>(Buf, isMipsR6() ? 0x7860 : 0x7980);  // addiupc v1, (GOTPLT) - .
    write16<E>(Buf + 4, 0xff23);    // lw      $25, 0($3)
    write16<E>(Buf + 8, 0x0535);    // subu16  $2,  $2, $3
    write16<E>(Buf + 10, 0x2525);   // srl16   $2,  $2, 2
    write16<E>(Buf + 12, 0x3302);   // addiu   $24, $2, -2
    write16<E>(Buf + 14, 0xfffe);
    write16<E>(Buf + 16, 0x0dff);   // move    $15, $31
    if (isMipsR6()) {
      write16<E>(Buf + 18, 0x0f83); // move    $28, $3
      write16<E>(Buf + 20, 0x472b); // jalrc   $25
      write16<E>(Buf + 22, 0x0c00); // nop
      relocateOne(Buf, R_MICROMIPS_PC19_S2, GotPlt - Plt);
    } else {
      write16<E>(Buf + 18, 0x45f9); // jalrc   $25
      write16<E>(Buf + 20, 0x0f83); // move    $28, $3
      write16<E>(Buf + 22, 0x0c00); // nop
      relocateOne(Buf, R_MICROMIPS_PC23_S2, GotPlt - Plt);
    }
    return;
  }

  if (Config->MipsN32Abi) {
    write32<E>(Buf, 0x3c0e0000);      // lui   $14, %hi(&GOTPLT[0])
    write32<E>(Buf + 4, 0x8dd90000);  // lw    $25, %lo(&GOTPLT[0])($14)
    write32<E>(Buf + 8, 0x25ce0000);  // addiu $14, $14, %lo(&GOTPLT[0])
    write32<E>(Buf + 12, 0x030ec023); // subu  $24, $24, $14
    write32<E>(Buf + 16, 0x03e07825); // move  $15, $31
    write32<E>(Buf + 20, 0x0018c082); // srl   $24, $24, 2
  } else if (ELFT::Is64Bits) {
    write32<E>(Buf, 0x3c0e0000);      // lui   $14, %hi(&GOTPLT[0])
    write32<E>(Buf + 4, 0xddd90000);  // ld    $25, %lo(&GOTPLT[0])($14)
    write32<E>(Buf + 8, 0x25ce0000);  // addiu $14, $14, %lo(&GOTPLT[0])
    write32<E>(Buf + 12, 0x030ec023); // subu  $24, $24, $14
    write32<E>(Buf + 16, 0x03e07825); // move  $15, $31
    write32<E>(Buf + 20, 0x0018c0c2); // srl   $24, $24, 3
  } else {
    write32<E>(Buf, 0x3c1c0000);      // lui   $28, %hi(&GOTPLT[0])
    write32<E>(Buf + 4, 0x8f990000);  // lw    $25, %lo(&GOTPLT[0])($28)
    write32<E>(Buf + 8, 0x279c0000);  // addiu $28, $28, %lo(&GOTPLT[0])
    write32<E>(Buf + 12, 0x031cc023); // subu  $24, $24, $28
    write32<E>(Buf + 16, 0x03e07825); // move  $15, $31
    write32<E>(Buf + 20, 0x0018c082); // srl   $24, $24, 2
  }

  write32<E>(Buf + 24, 0x0320f809); // jalr  $25
  write32<E>(Buf + 28, 0x2718fffe); // subu  $24, $24, 2

  uint64_t GotPlt = InX::GotPlt->getVA();
  writeRelocation<E>(Buf, GotPlt + 0x8000, 16, 16);
  writeRelocation<E>(Buf + 4, GotPlt, 16, 0);
  writeRelocation<E>(Buf + 8, GotPlt, 16, 0);
}

template <class ELFT>
void MIPS<ELFT>::writePlt(uint8_t *Buf, uint64_t GotPltEntryAddr,
                          uint64_t PltEntryAddr, int32_t Index,
                          unsigned RelOff) const {
  const endianness E = ELFT::TargetEndianness;
  if (isMicroMips()) {
    // Overwrite trap instructions written by Writer::writeTrapInstr.
    memset(Buf, 0, PltEntrySize);

    if (isMipsR6()) {
      write16<E>(Buf, 0x7840);      // addiupc $2, (GOTPLT) - .
      write16<E>(Buf + 4, 0xff22);  // lw $25, 0($2)
      write16<E>(Buf + 8, 0x0f02);  // move $24, $2
      write16<E>(Buf + 10, 0x4723); // jrc $25 / jr16 $25
      relocateOne(Buf, R_MICROMIPS_PC19_S2, GotPltEntryAddr - PltEntryAddr);
    } else {
      write16<E>(Buf, 0x7900);      // addiupc $2, (GOTPLT) - .
      write16<E>(Buf + 4, 0xff22);  // lw $25, 0($2)
      write16<E>(Buf + 8, 0x4599);  // jrc $25 / jr16 $25
      write16<E>(Buf + 10, 0x0f02); // move $24, $2
      relocateOne(Buf, R_MICROMIPS_PC23_S2, GotPltEntryAddr - PltEntryAddr);
    }
    return;
  }

  write32<E>(Buf, 0x3c0f0000);     // lui   $15, %hi(.got.plt entry)
  write32<E>(Buf + 4, 0x8df90000); // l[wd] $25, %lo(.got.plt entry)($15)
  write32<E>(Buf + 8, isMipsR6() ? 0x03200009 : 0x03200008);  // jr  $25
  write32<E>(Buf + 12, 0x25f80000); // addiu $24, $15, %lo(.got.plt entry)
  writeRelocation<E>(Buf, GotPltEntryAddr + 0x8000, 16, 16);
  writeRelocation<E>(Buf + 4, GotPltEntryAddr, 16, 0);
  writeRelocation<E>(Buf + 12, GotPltEntryAddr, 16, 0);
}

template <class ELFT>
bool MIPS<ELFT>::needsThunk(RelExpr Expr, RelType Type, const InputFile *File,
                            uint64_t BranchAddr, const Symbol &S) const {
  // Any MIPS PIC code function is invoked with its address in register $t9.
  // So if we have a branch instruction from non-PIC code to the PIC one
  // we cannot make the jump directly and need to create a small stubs
  // to save the target function address.
  // See page 3-38 ftp://www.linux-mips.org/pub/linux/mips/doc/ABI/mipsabi.pdf
  if (Type != R_MIPS_26 && Type != R_MICROMIPS_26_S1 &&
      Type != R_MICROMIPS_PC26_S1)
    return false;
  auto *F = dyn_cast_or_null<ELFFileBase<ELFT>>(File);
  if (!F)
    return false;
  // If current file has PIC code, LA25 stub is not required.
  if (F->getObj().getHeader()->e_flags & EF_MIPS_PIC)
    return false;
  auto *D = dyn_cast<Defined>(&S);
  // LA25 is required if target file has PIC code
  // or target symbol is a PIC symbol.
  return D && isMipsPIC<ELFT>(D);
}

template <class ELFT>
int64_t MIPS<ELFT>::getImplicitAddend(const uint8_t *Buf, RelType Type) const {
  const endianness E = ELFT::TargetEndianness;
  switch (Type) {
  case R_MIPS_32:
  case R_MIPS_GPREL32:
  case R_MIPS_TLS_DTPREL32:
  case R_MIPS_TLS_TPREL32:
    return SignExtend64<32>(read32<E>(Buf));
  case R_MIPS_26:
    // FIXME (simon): If the relocation target symbol is not a PLT entry
    // we should use another expression for calculation:
    // ((A << 2) | (P & 0xf0000000)) >> 2
    return SignExtend64<28>(read32<E>(Buf) << 2);
  case R_MIPS_GOT16:
  case R_MIPS_HI16:
  case R_MIPS_PCHI16:
    return SignExtend64<16>(read32<E>(Buf)) << 16;
  case R_MIPS_GPREL16:
  case R_MIPS_LO16:
  case R_MIPS_PCLO16:
  case R_MIPS_TLS_DTPREL_HI16:
  case R_MIPS_TLS_DTPREL_LO16:
  case R_MIPS_TLS_TPREL_HI16:
  case R_MIPS_TLS_TPREL_LO16:
    return SignExtend64<16>(read32<E>(Buf));
  case R_MICROMIPS_GOT16:
  case R_MICROMIPS_HI16:
    return SignExtend64<16>(readShuffle<E>(Buf)) << 16;
  case R_MICROMIPS_GPREL16:
  case R_MICROMIPS_LO16:
  case R_MICROMIPS_TLS_DTPREL_HI16:
  case R_MICROMIPS_TLS_DTPREL_LO16:
  case R_MICROMIPS_TLS_TPREL_HI16:
  case R_MICROMIPS_TLS_TPREL_LO16:
    return SignExtend64<16>(readShuffle<E>(Buf));
  case R_MICROMIPS_GPREL7_S2:
    return SignExtend64<9>(readShuffle<E>(Buf) << 2);
  case R_MIPS_PC16:
    return SignExtend64<18>(read32<E>(Buf) << 2);
  case R_MIPS_PC19_S2:
    return SignExtend64<21>(read32<E>(Buf) << 2);
  case R_MIPS_PC21_S2:
    return SignExtend64<23>(read32<E>(Buf) << 2);
  case R_MIPS_PC26_S2:
    return SignExtend64<28>(read32<E>(Buf) << 2);
  case R_MIPS_PC32:
    return SignExtend64<32>(read32<E>(Buf));
  case R_MICROMIPS_26_S1:
    return SignExtend64<27>(readShuffle<E>(Buf) << 1);
  case R_MICROMIPS_PC7_S1:
    return SignExtend64<8>(read16<E>(Buf) << 1);
  case R_MICROMIPS_PC10_S1:
    return SignExtend64<11>(read16<E>(Buf) << 1);
  case R_MICROMIPS_PC16_S1:
    return SignExtend64<17>(readShuffle<E>(Buf) << 1);
  case R_MICROMIPS_PC18_S3:
    return SignExtend64<21>(readShuffle<E>(Buf) << 3);
  case R_MICROMIPS_PC19_S2:
    return SignExtend64<21>(readShuffle<E>(Buf) << 2);
  case R_MICROMIPS_PC21_S1:
    return SignExtend64<22>(readShuffle<E>(Buf) << 1);
  case R_MICROMIPS_PC23_S2:
    return SignExtend64<25>(readShuffle<E>(Buf) << 2);
  case R_MICROMIPS_PC26_S1:
    return SignExtend64<27>(readShuffle<E>(Buf) << 1);
  default:
    return 0;
  }
}

static std::pair<uint32_t, uint64_t>
calculateMipsRelChain(uint8_t *Loc, RelType Type, uint64_t Val) {
  // MIPS N64 ABI packs multiple relocations into the single relocation
  // record. In general, all up to three relocations can have arbitrary
  // types. In fact, Clang and GCC uses only a few combinations. For now,
  // we support two of them. That is allow to pass at least all LLVM
  // test suite cases.
  // <any relocation> / R_MIPS_SUB / R_MIPS_HI16 | R_MIPS_LO16
  // <any relocation> / R_MIPS_64 / R_MIPS_NONE
  // The first relocation is a 'real' relocation which is calculated
  // using the corresponding symbol's value. The second and the third
  // relocations used to modify result of the first one: extend it to
  // 64-bit, extract high or low part etc. For details, see part 2.9 Relocation
  // at the https://dmz-portal.mips.com/mw/images/8/82/007-4658-001.pdf
  RelType Type2 = (Type >> 8) & 0xff;
  RelType Type3 = (Type >> 16) & 0xff;
  if (Type2 == R_MIPS_NONE && Type3 == R_MIPS_NONE)
    return std::make_pair(Type, Val);
  if (Type2 == R_MIPS_64 && Type3 == R_MIPS_NONE)
    return std::make_pair(Type2, Val);
  if (Type2 == R_MIPS_SUB && (Type3 == R_MIPS_HI16 || Type3 == R_MIPS_LO16))
    return std::make_pair(Type3, -Val);
  if (Type2 == R_MICROMIPS_SUB &&
      (Type3 == R_MICROMIPS_HI16 || Type3 == R_MICROMIPS_LO16))
    return std::make_pair(Type3, -Val);
  error(getErrorLocation(Loc) + "unsupported relocations combination " +
        Twine(Type));
  return std::make_pair(Type & 0xff, Val);
}

template <class ELFT>
void MIPS<ELFT>::relocateOne(uint8_t *Loc, RelType Type, uint64_t Val) const {
  const endianness E = ELFT::TargetEndianness;

  // Thread pointer and DRP offsets from the start of TLS data area.
  // https://www.linux-mips.org/wiki/NPTL
  if (Type == R_MIPS_TLS_DTPREL_HI16 || Type == R_MIPS_TLS_DTPREL_LO16 ||
      Type == R_MIPS_TLS_DTPREL32 || Type == R_MIPS_TLS_DTPREL64 ||
      Type == R_MICROMIPS_TLS_DTPREL_HI16 ||
      Type == R_MICROMIPS_TLS_DTPREL_LO16) {
    Val -= 0x8000;
  } else if (Type == R_MIPS_TLS_TPREL_HI16 || Type == R_MIPS_TLS_TPREL_LO16 ||
             Type == R_MIPS_TLS_TPREL32 || Type == R_MIPS_TLS_TPREL64 ||
             Type == R_MICROMIPS_TLS_TPREL_HI16 ||
             Type == R_MICROMIPS_TLS_TPREL_LO16) {
    Val -= 0x7000;
  }

  if (ELFT::Is64Bits || Config->MipsN32Abi)
    std::tie(Type, Val) = calculateMipsRelChain(Loc, Type, Val);

  switch (Type) {
  case R_MIPS_32:
  case R_MIPS_GPREL32:
  case R_MIPS_TLS_DTPREL32:
  case R_MIPS_TLS_TPREL32:
    write32<E>(Loc, Val);
    break;
  case R_MIPS_64:
  case R_MIPS_TLS_DTPREL64:
  case R_MIPS_TLS_TPREL64:
    write64<E>(Loc, Val);
    break;
  case R_MIPS_26:
    writeRelocation<E>(Loc, Val, 26, 2);
    break;
  case R_MIPS_GOT16:
    // The R_MIPS_GOT16 relocation's value in "relocatable" linking mode
    // is updated addend (not a GOT index). In that case write high 16 bits
    // to store a correct addend value.
    if (Config->Relocatable) {
      writeRelocation<E>(Loc, Val + 0x8000, 16, 16);
    } else {
      checkInt<16>(Loc, Val, Type);
      writeRelocation<E>(Loc, Val, 16, 0);
    }
    break;
  case R_MICROMIPS_GOT16:
    if (Config->Relocatable) {
      writeMicroRelocation32<E>(Loc, Val + 0x8000, 16, 16);
    } else {
      checkInt<16>(Loc, Val, Type);
      writeMicroRelocation32<E>(Loc, Val, 16, 0);
    }
    break;
  case R_MIPS_CALL16:
  case R_MIPS_GOT_DISP:
  case R_MIPS_GOT_PAGE:
  case R_MIPS_GPREL16:
  case R_MIPS_TLS_GD:
  case R_MIPS_TLS_GOTTPREL:
  case R_MIPS_TLS_LDM:
    checkInt<16>(Loc, Val, Type);
    LLVM_FALLTHROUGH;
  case R_MIPS_CALL_LO16:
  case R_MIPS_GOT_LO16:
  case R_MIPS_GOT_OFST:
  case R_MIPS_LO16:
  case R_MIPS_PCLO16:
  case R_MIPS_TLS_DTPREL_LO16:
  case R_MIPS_TLS_TPREL_LO16:
    writeRelocation<E>(Loc, Val, 16, 0);
    break;
  case R_MICROMIPS_GOT_DISP:
  case R_MICROMIPS_GOT_PAGE:
  case R_MICROMIPS_GPREL16:
  case R_MICROMIPS_TLS_GD:
  case R_MICROMIPS_TLS_LDM:
    checkInt<16>(Loc, Val, Type);
    writeMicroRelocation32<E>(Loc, Val, 16, 0);
    break;
  case R_MICROMIPS_CALL16:
  case R_MICROMIPS_CALL_LO16:
  case R_MICROMIPS_GOT_OFST:
  case R_MICROMIPS_LO16:
  case R_MICROMIPS_TLS_DTPREL_LO16:
  case R_MICROMIPS_TLS_GOTTPREL:
  case R_MICROMIPS_TLS_TPREL_LO16:
    writeMicroRelocation32<E>(Loc, Val, 16, 0);
    break;
  case R_MICROMIPS_GPREL7_S2:
    checkInt<7>(Loc, Val, Type);
    writeMicroRelocation32<E>(Loc, Val, 7, 2);
    break;
  case R_MIPS_CALL_HI16:
  case R_MIPS_GOT_HI16:
  case R_MIPS_HI16:
  case R_MIPS_PCHI16:
  case R_MIPS_TLS_DTPREL_HI16:
  case R_MIPS_TLS_TPREL_HI16:
    writeRelocation<E>(Loc, Val + 0x8000, 16, 16);
    break;
  case R_MICROMIPS_CALL_HI16:
  case R_MICROMIPS_GOT_HI16:
  case R_MICROMIPS_HI16:
  case R_MICROMIPS_TLS_DTPREL_HI16:
  case R_MICROMIPS_TLS_TPREL_HI16:
    writeMicroRelocation32<E>(Loc, Val + 0x8000, 16, 16);
    break;
  case R_MIPS_HIGHER:
    writeRelocation<E>(Loc, Val + 0x80008000, 16, 32);
    break;
  case R_MIPS_HIGHEST:
    writeRelocation<E>(Loc, Val + 0x800080008000, 16, 48);
    break;
  case R_MICROMIPS_HIGHER:
    writeMicroRelocation32<E>(Loc, Val + 0x80008000, 16, 32);
    break;
  case R_MICROMIPS_HIGHEST:
    writeMicroRelocation32<E>(Loc, Val + 0x800080008000, 16, 48);
    break;
  case R_MIPS_JALR:
  case R_MICROMIPS_JALR:
    // Ignore this optimization relocation for now
    break;
  case R_MIPS_PC16:
    checkAlignment<4>(Loc, Val, Type);
    checkInt<18>(Loc, Val, Type);
    writeRelocation<E>(Loc, Val, 16, 2);
    break;
  case R_MIPS_PC19_S2:
    checkAlignment<4>(Loc, Val, Type);
    checkInt<21>(Loc, Val, Type);
    writeRelocation<E>(Loc, Val, 19, 2);
    break;
  case R_MIPS_PC21_S2:
    checkAlignment<4>(Loc, Val, Type);
    checkInt<23>(Loc, Val, Type);
    writeRelocation<E>(Loc, Val, 21, 2);
    break;
  case R_MIPS_PC26_S2:
    checkAlignment<4>(Loc, Val, Type);
    checkInt<28>(Loc, Val, Type);
    writeRelocation<E>(Loc, Val, 26, 2);
    break;
  case R_MIPS_PC32:
    writeRelocation<E>(Loc, Val, 32, 0);
    break;
  case R_MICROMIPS_26_S1:
  case R_MICROMIPS_PC26_S1:
    checkInt<27>(Loc, Val, Type);
    writeMicroRelocation32<E>(Loc, Val, 26, 1);
    break;
  case R_MICROMIPS_PC7_S1:
    checkInt<8>(Loc, Val, Type);
    writeMicroRelocation16<E>(Loc, Val, 7, 1);
    break;
  case R_MICROMIPS_PC10_S1:
    checkInt<11>(Loc, Val, Type);
    writeMicroRelocation16<E>(Loc, Val, 10, 1);
    break;
  case R_MICROMIPS_PC16_S1:
    checkInt<17>(Loc, Val, Type);
    writeMicroRelocation32<E>(Loc, Val, 16, 1);
    break;
  case R_MICROMIPS_PC18_S3:
    checkInt<21>(Loc, Val, Type);
    writeMicroRelocation32<E>(Loc, Val, 18, 3);
    break;
  case R_MICROMIPS_PC19_S2:
    checkInt<21>(Loc, Val, Type);
    writeMicroRelocation32<E>(Loc, Val, 19, 2);
    break;
  case R_MICROMIPS_PC21_S1:
    checkInt<22>(Loc, Val, Type);
    writeMicroRelocation32<E>(Loc, Val, 21, 1);
    break;
  case R_MICROMIPS_PC23_S2:
    checkInt<25>(Loc, Val, Type);
    writeMicroRelocation32<E>(Loc, Val, 23, 2);
    break;
  default:
    error(getErrorLocation(Loc) + "unrecognized reloc " + Twine(Type));
  }
}

template <class ELFT> bool MIPS<ELFT>::usesOnlyLowPageBits(RelType Type) const {
  return Type == R_MIPS_LO16 || Type == R_MIPS_GOT_OFST ||
         Type == R_MICROMIPS_LO16 || Type == R_MICROMIPS_GOT_OFST;
}

// Return true if the symbol is a PIC function.
template <class ELFT> bool elf::isMipsPIC(const Defined *Sym) {
  typedef typename ELFT::Ehdr Elf_Ehdr;
  if (!Sym->Section || !Sym->isFunc())
    return false;

  auto *Sec = cast<InputSectionBase>(Sym->Section);
  const Elf_Ehdr *Hdr = Sec->template getFile<ELFT>()->getObj().getHeader();
  return (Sym->StOther & STO_MIPS_MIPS16) == STO_MIPS_PIC ||
         (Hdr->e_flags & EF_MIPS_PIC);
}

template <class ELFT> TargetInfo *elf::getMipsTargetInfo() {
  static MIPS<ELFT> Target;
  return &Target;
}

template TargetInfo *elf::getMipsTargetInfo<ELF32LE>();
template TargetInfo *elf::getMipsTargetInfo<ELF32BE>();
template TargetInfo *elf::getMipsTargetInfo<ELF64LE>();
template TargetInfo *elf::getMipsTargetInfo<ELF64BE>();

template bool elf::isMipsPIC<ELF32LE>(const Defined *);
template bool elf::isMipsPIC<ELF32BE>(const Defined *);
template bool elf::isMipsPIC<ELF64LE>(const Defined *);
template bool elf::isMipsPIC<ELF64BE>(const Defined *);
