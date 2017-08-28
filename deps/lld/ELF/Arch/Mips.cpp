//===- MIPS.cpp -----------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "Error.h"
#include "InputFiles.h"
#include "OutputSections.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "Thunks.h"
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
  RelExpr getRelExpr(uint32_t Type, const SymbolBody &S,
                     const uint8_t *Loc) const override;
  int64_t getImplicitAddend(const uint8_t *Buf, uint32_t Type) const override;
  bool isPicRel(uint32_t Type) const override;
  uint32_t getDynRel(uint32_t Type) const override;
  void writeGotPlt(uint8_t *Buf, const SymbolBody &S) const override;
  void writePltHeader(uint8_t *Buf) const override;
  void writePlt(uint8_t *Buf, uint64_t GotPltEntryAddr, uint64_t PltEntryAddr,
                int32_t Index, unsigned RelOff) const override;
  bool needsThunk(RelExpr Expr, uint32_t RelocType, const InputFile *File,
                  const SymbolBody &S) const override;
  void relocateOne(uint8_t *Loc, uint32_t Type, uint64_t Val) const override;
  bool usesOnlyLowPageBits(uint32_t Type) const override;
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

template <class ELFT>
RelExpr MIPS<ELFT>::getRelExpr(uint32_t Type, const SymbolBody &S,
                               const uint8_t *Loc) const {
  // See comment in the calculateMipsRelChain.
  if (ELFT::Is64Bits || Config->MipsN32Abi)
    Type &= 0xff;
  switch (Type) {
  default:
    return R_ABS;
  case R_MIPS_JALR:
    return R_HINT;
  case R_MIPS_GPREL16:
  case R_MIPS_GPREL32:
    return R_MIPS_GOTREL;
  case R_MIPS_26:
    return R_PLT;
  case R_MIPS_HI16:
  case R_MIPS_LO16:
    // R_MIPS_HI16/R_MIPS_LO16 relocations against _gp_disp calculate
    // offset between start of function and 'gp' value which by default
    // equal to the start of .got section. In that case we consider these
    // relocations as relative.
    if (&S == ElfSym::MipsGpDisp)
      return R_MIPS_GOT_GP_PC;
    if (&S == ElfSym::MipsLocalGp)
      return R_MIPS_GOT_GP;
    LLVM_FALLTHROUGH;
  case R_MIPS_GOT_OFST:
    return R_ABS;
  case R_MIPS_PC32:
  case R_MIPS_PC16:
  case R_MIPS_PC19_S2:
  case R_MIPS_PC21_S2:
  case R_MIPS_PC26_S2:
  case R_MIPS_PCHI16:
  case R_MIPS_PCLO16:
    return R_PC;
  case R_MIPS_GOT16:
    if (S.isLocal())
      return R_MIPS_GOT_LOCAL_PAGE;
    LLVM_FALLTHROUGH;
  case R_MIPS_CALL16:
  case R_MIPS_GOT_DISP:
  case R_MIPS_TLS_GOTTPREL:
    return R_MIPS_GOT_OFF;
  case R_MIPS_CALL_HI16:
  case R_MIPS_CALL_LO16:
  case R_MIPS_GOT_HI16:
  case R_MIPS_GOT_LO16:
    return R_MIPS_GOT_OFF32;
  case R_MIPS_GOT_PAGE:
    return R_MIPS_GOT_LOCAL_PAGE;
  case R_MIPS_TLS_GD:
    return R_MIPS_TLSGD;
  case R_MIPS_TLS_LDM:
    return R_MIPS_TLSLD;
  }
}

template <class ELFT> bool MIPS<ELFT>::isPicRel(uint32_t Type) const {
  return Type == R_MIPS_32 || Type == R_MIPS_64;
}

template <class ELFT> uint32_t MIPS<ELFT>::getDynRel(uint32_t Type) const {
  return RelativeRel;
}

template <class ELFT>
void MIPS<ELFT>::writeGotPlt(uint8_t *Buf, const SymbolBody &) const {
  write32<ELFT::TargetEndianness>(Buf, InX::Plt->getVA());
}

template <endianness E, uint8_t BSIZE, uint8_t SHIFT>
static int64_t getPcRelocAddend(const uint8_t *Loc) {
  uint32_t Instr = read32<E>(Loc);
  uint32_t Mask = 0xffffffff >> (32 - BSIZE);
  return SignExtend64<BSIZE + SHIFT>((Instr & Mask) << SHIFT);
}

template <endianness E, uint8_t BSIZE, uint8_t SHIFT>
static void applyMipsPcReloc(uint8_t *Loc, uint32_t Type, uint64_t V) {
  uint32_t Mask = 0xffffffff >> (32 - BSIZE);
  uint32_t Instr = read32<E>(Loc);
  if (SHIFT > 0)
    checkAlignment<(1 << SHIFT)>(Loc, V, Type);
  checkInt<BSIZE + SHIFT>(Loc, V, Type);
  write32<E>(Loc, (Instr & ~Mask) | ((V >> SHIFT) & Mask));
}

template <endianness E> static void writeMipsHi16(uint8_t *Loc, uint64_t V) {
  uint32_t Instr = read32<E>(Loc);
  uint16_t Res = ((V + 0x8000) >> 16) & 0xffff;
  write32<E>(Loc, (Instr & 0xffff0000) | Res);
}

template <endianness E> static void writeMipsHigher(uint8_t *Loc, uint64_t V) {
  uint32_t Instr = read32<E>(Loc);
  uint16_t Res = ((V + 0x80008000) >> 32) & 0xffff;
  write32<E>(Loc, (Instr & 0xffff0000) | Res);
}

template <endianness E> static void writeMipsHighest(uint8_t *Loc, uint64_t V) {
  uint32_t Instr = read32<E>(Loc);
  uint16_t Res = ((V + 0x800080008000) >> 48) & 0xffff;
  write32<E>(Loc, (Instr & 0xffff0000) | Res);
}

template <endianness E> static void writeMipsLo16(uint8_t *Loc, uint64_t V) {
  uint32_t Instr = read32<E>(Loc);
  write32<E>(Loc, (Instr & 0xffff0000) | (V & 0xffff));
}

template <class ELFT> static bool isMipsR6() {
  const auto &FirstObj = cast<ELFFileBase<ELFT>>(*Config->FirstElf);
  uint32_t Arch = FirstObj.getObj().getHeader()->e_flags & EF_MIPS_ARCH;
  return Arch == EF_MIPS_ARCH_32R6 || Arch == EF_MIPS_ARCH_64R6;
}

template <class ELFT> void MIPS<ELFT>::writePltHeader(uint8_t *Buf) const {
  const endianness E = ELFT::TargetEndianness;
  if (Config->MipsN32Abi) {
    write32<E>(Buf, 0x3c0e0000);      // lui   $14, %hi(&GOTPLT[0])
    write32<E>(Buf + 4, 0x8dd90000);  // lw    $25, %lo(&GOTPLT[0])($14)
    write32<E>(Buf + 8, 0x25ce0000);  // addiu $14, $14, %lo(&GOTPLT[0])
    write32<E>(Buf + 12, 0x030ec023); // subu  $24, $24, $14
  } else {
    write32<E>(Buf, 0x3c1c0000);      // lui   $28, %hi(&GOTPLT[0])
    write32<E>(Buf + 4, 0x8f990000);  // lw    $25, %lo(&GOTPLT[0])($28)
    write32<E>(Buf + 8, 0x279c0000);  // addiu $28, $28, %lo(&GOTPLT[0])
    write32<E>(Buf + 12, 0x031cc023); // subu  $24, $24, $28
  }

  write32<E>(Buf + 16, 0x03e07825); // move  $15, $31
  write32<E>(Buf + 20, 0x0018c082); // srl   $24, $24, 2
  write32<E>(Buf + 24, 0x0320f809); // jalr  $25
  write32<E>(Buf + 28, 0x2718fffe); // subu  $24, $24, 2

  uint64_t GotPlt = InX::GotPlt->getVA();
  writeMipsHi16<E>(Buf, GotPlt);
  writeMipsLo16<E>(Buf + 4, GotPlt);
  writeMipsLo16<E>(Buf + 8, GotPlt);
}

template <class ELFT>
void MIPS<ELFT>::writePlt(uint8_t *Buf, uint64_t GotPltEntryAddr,
                          uint64_t PltEntryAddr, int32_t Index,
                          unsigned RelOff) const {
  const endianness E = ELFT::TargetEndianness;
  write32<E>(Buf, 0x3c0f0000);     // lui   $15, %hi(.got.plt entry)
  write32<E>(Buf + 4, 0x8df90000); // l[wd] $25, %lo(.got.plt entry)($15)
                                   // jr    $25
  write32<E>(Buf + 8, isMipsR6<ELFT>() ? 0x03200009 : 0x03200008);
  write32<E>(Buf + 12, 0x25f80000); // addiu $24, $15, %lo(.got.plt entry)
  writeMipsHi16<E>(Buf, GotPltEntryAddr);
  writeMipsLo16<E>(Buf + 4, GotPltEntryAddr);
  writeMipsLo16<E>(Buf + 12, GotPltEntryAddr);
}

template <class ELFT>
bool MIPS<ELFT>::needsThunk(RelExpr Expr, uint32_t Type, const InputFile *File,
                            const SymbolBody &S) const {
  // Any MIPS PIC code function is invoked with its address in register $t9.
  // So if we have a branch instruction from non-PIC code to the PIC one
  // we cannot make the jump directly and need to create a small stubs
  // to save the target function address.
  // See page 3-38 ftp://www.linux-mips.org/pub/linux/mips/doc/ABI/mipsabi.pdf
  if (Type != R_MIPS_26)
    return false;
  auto *F = dyn_cast_or_null<ELFFileBase<ELFT>>(File);
  if (!F)
    return false;
  // If current file has PIC code, LA25 stub is not required.
  if (F->getObj().getHeader()->e_flags & EF_MIPS_PIC)
    return false;
  auto *D = dyn_cast<DefinedRegular>(&S);
  // LA25 is required if target file has PIC code
  // or target symbol is a PIC symbol.
  return D && D->isMipsPIC<ELFT>();
}

template <class ELFT>
int64_t MIPS<ELFT>::getImplicitAddend(const uint8_t *Buf, uint32_t Type) const {
  const endianness E = ELFT::TargetEndianness;
  switch (Type) {
  default:
    return 0;
  case R_MIPS_32:
  case R_MIPS_GPREL32:
  case R_MIPS_TLS_DTPREL32:
  case R_MIPS_TLS_TPREL32:
    return SignExtend64<32>(read32<E>(Buf));
  case R_MIPS_26:
    // FIXME (simon): If the relocation target symbol is not a PLT entry
    // we should use another expression for calculation:
    // ((A << 2) | (P & 0xf0000000)) >> 2
    return SignExtend64<28>((read32<E>(Buf) & 0x3ffffff) << 2);
  case R_MIPS_GPREL16:
  case R_MIPS_LO16:
  case R_MIPS_PCLO16:
  case R_MIPS_TLS_DTPREL_HI16:
  case R_MIPS_TLS_DTPREL_LO16:
  case R_MIPS_TLS_TPREL_HI16:
  case R_MIPS_TLS_TPREL_LO16:
    return SignExtend64<16>(read32<E>(Buf));
  case R_MIPS_PC16:
    return getPcRelocAddend<E, 16, 2>(Buf);
  case R_MIPS_PC19_S2:
    return getPcRelocAddend<E, 19, 2>(Buf);
  case R_MIPS_PC21_S2:
    return getPcRelocAddend<E, 21, 2>(Buf);
  case R_MIPS_PC26_S2:
    return getPcRelocAddend<E, 26, 2>(Buf);
  case R_MIPS_PC32:
    return getPcRelocAddend<E, 32, 0>(Buf);
  }
}

static std::pair<uint32_t, uint64_t>
calculateMipsRelChain(uint8_t *Loc, uint32_t Type, uint64_t Val) {
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
  uint32_t Type2 = (Type >> 8) & 0xff;
  uint32_t Type3 = (Type >> 16) & 0xff;
  if (Type2 == R_MIPS_NONE && Type3 == R_MIPS_NONE)
    return std::make_pair(Type, Val);
  if (Type2 == R_MIPS_64 && Type3 == R_MIPS_NONE)
    return std::make_pair(Type2, Val);
  if (Type2 == R_MIPS_SUB && (Type3 == R_MIPS_HI16 || Type3 == R_MIPS_LO16))
    return std::make_pair(Type3, -Val);
  error(getErrorLocation(Loc) + "unsupported relocations combination " +
        Twine(Type));
  return std::make_pair(Type & 0xff, Val);
}

template <class ELFT>
void MIPS<ELFT>::relocateOne(uint8_t *Loc, uint32_t Type, uint64_t Val) const {
  const endianness E = ELFT::TargetEndianness;
  // Thread pointer and DRP offsets from the start of TLS data area.
  // https://www.linux-mips.org/wiki/NPTL
  if (Type == R_MIPS_TLS_DTPREL_HI16 || Type == R_MIPS_TLS_DTPREL_LO16 ||
      Type == R_MIPS_TLS_DTPREL32 || Type == R_MIPS_TLS_DTPREL64)
    Val -= 0x8000;
  else if (Type == R_MIPS_TLS_TPREL_HI16 || Type == R_MIPS_TLS_TPREL_LO16 ||
           Type == R_MIPS_TLS_TPREL32 || Type == R_MIPS_TLS_TPREL64)
    Val -= 0x7000;
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
    write32<E>(Loc, (read32<E>(Loc) & ~0x3ffffff) | ((Val >> 2) & 0x3ffffff));
    break;
  case R_MIPS_GOT16:
    // The R_MIPS_GOT16 relocation's value in "relocatable" linking mode
    // is updated addend (not a GOT index). In that case write high 16 bits
    // to store a correct addend value.
    if (Config->Relocatable)
      writeMipsHi16<E>(Loc, Val);
    else {
      checkInt<16>(Loc, Val, Type);
      writeMipsLo16<E>(Loc, Val);
    }
    break;
  case R_MIPS_GOT_DISP:
  case R_MIPS_GOT_PAGE:
  case R_MIPS_GPREL16:
  case R_MIPS_TLS_GD:
  case R_MIPS_TLS_LDM:
    checkInt<16>(Loc, Val, Type);
    LLVM_FALLTHROUGH;
  case R_MIPS_CALL16:
  case R_MIPS_CALL_LO16:
  case R_MIPS_GOT_LO16:
  case R_MIPS_GOT_OFST:
  case R_MIPS_LO16:
  case R_MIPS_PCLO16:
  case R_MIPS_TLS_DTPREL_LO16:
  case R_MIPS_TLS_GOTTPREL:
  case R_MIPS_TLS_TPREL_LO16:
    writeMipsLo16<E>(Loc, Val);
    break;
  case R_MIPS_CALL_HI16:
  case R_MIPS_GOT_HI16:
  case R_MIPS_HI16:
  case R_MIPS_PCHI16:
  case R_MIPS_TLS_DTPREL_HI16:
  case R_MIPS_TLS_TPREL_HI16:
    writeMipsHi16<E>(Loc, Val);
    break;
  case R_MIPS_HIGHER:
    writeMipsHigher<E>(Loc, Val);
    break;
  case R_MIPS_HIGHEST:
    writeMipsHighest<E>(Loc, Val);
    break;
  case R_MIPS_JALR:
    // Ignore this optimization relocation for now
    break;
  case R_MIPS_PC16:
    applyMipsPcReloc<E, 16, 2>(Loc, Type, Val);
    break;
  case R_MIPS_PC19_S2:
    applyMipsPcReloc<E, 19, 2>(Loc, Type, Val);
    break;
  case R_MIPS_PC21_S2:
    applyMipsPcReloc<E, 21, 2>(Loc, Type, Val);
    break;
  case R_MIPS_PC26_S2:
    applyMipsPcReloc<E, 26, 2>(Loc, Type, Val);
    break;
  case R_MIPS_PC32:
    applyMipsPcReloc<E, 32, 0>(Loc, Type, Val);
    break;
  default:
    error(getErrorLocation(Loc) + "unrecognized reloc " + Twine(Type));
  }
}

template <class ELFT>
bool MIPS<ELFT>::usesOnlyLowPageBits(uint32_t Type) const {
  return Type == R_MIPS_LO16 || Type == R_MIPS_GOT_OFST;
}

template <class ELFT> TargetInfo *elf::getMipsTargetInfo() {
  static MIPS<ELFT> Target;
  return &Target;
}

template TargetInfo *elf::getMipsTargetInfo<ELF32LE>();
template TargetInfo *elf::getMipsTargetInfo<ELF32BE>();
template TargetInfo *elf::getMipsTargetInfo<ELF64LE>();
template TargetInfo *elf::getMipsTargetInfo<ELF64BE>();
