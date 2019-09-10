//===- PPC64.cpp ----------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "Symbols.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/Support/Endian.h"

using namespace llvm;
using namespace llvm::object;
using namespace llvm::support::endian;
using namespace llvm::ELF;
using namespace lld;
using namespace lld::elf;

static uint64_t ppc64TocOffset = 0x8000;
static uint64_t dynamicThreadPointerOffset = 0x8000;

// The instruction encoding of bits 21-30 from the ISA for the Xform and Dform
// instructions that can be used as part of the initial exec TLS sequence.
enum XFormOpcd {
  LBZX = 87,
  LHZX = 279,
  LWZX = 23,
  LDX = 21,
  STBX = 215,
  STHX = 407,
  STWX = 151,
  STDX = 149,
  ADD = 266,
};

enum DFormOpcd {
  LBZ = 34,
  LBZU = 35,
  LHZ = 40,
  LHZU = 41,
  LHAU = 43,
  LWZ = 32,
  LWZU = 33,
  LFSU = 49,
  LD = 58,
  LFDU = 51,
  STB = 38,
  STBU = 39,
  STH = 44,
  STHU = 45,
  STW = 36,
  STWU = 37,
  STFSU = 53,
  STFDU = 55,
  STD = 62,
  ADDI = 14
};

uint64_t elf::getPPC64TocBase() {
  // The TOC consists of sections .got, .toc, .tocbss, .plt in that order. The
  // TOC starts where the first of these sections starts. We always create a
  // .got when we see a relocation that uses it, so for us the start is always
  // the .got.
  uint64_t tocVA = in.got->getVA();

  // Per the ppc64-elf-linux ABI, The TOC base is TOC value plus 0x8000
  // thus permitting a full 64 Kbytes segment. Note that the glibc startup
  // code (crt1.o) assumes that you can get from the TOC base to the
  // start of the .toc section with only a single (signed) 16-bit relocation.
  return tocVA + ppc64TocOffset;
}

unsigned elf::getPPC64GlobalEntryToLocalEntryOffset(uint8_t stOther) {
  // The offset is encoded into the 3 most significant bits of the st_other
  // field, with some special values described in section 3.4.1 of the ABI:
  // 0   --> Zero offset between the GEP and LEP, and the function does NOT use
  //         the TOC pointer (r2). r2 will hold the same value on returning from
  //         the function as it did on entering the function.
  // 1   --> Zero offset between the GEP and LEP, and r2 should be treated as a
  //         caller-saved register for all callers.
  // 2-6 --> The  binary logarithm of the offset eg:
  //         2 --> 2^2 = 4 bytes -->  1 instruction.
  //         6 --> 2^6 = 64 bytes --> 16 instructions.
  // 7   --> Reserved.
  uint8_t gepToLep = (stOther >> 5) & 7;
  if (gepToLep < 2)
    return 0;

  // The value encoded in the st_other bits is the
  // log-base-2(offset).
  if (gepToLep < 7)
    return 1 << gepToLep;

  error("reserved value of 7 in the 3 most-significant-bits of st_other");
  return 0;
}

bool elf::isPPC64SmallCodeModelTocReloc(RelType type) {
  // The only small code model relocations that access the .toc section.
  return type == R_PPC64_TOC16 || type == R_PPC64_TOC16_DS;
}

// Find the R_PPC64_ADDR64 in .rela.toc with matching offset.
template <typename ELFT>
static std::pair<Defined *, int64_t>
getRelaTocSymAndAddend(InputSectionBase *tocSec, uint64_t offset) {
  if (tocSec->numRelocations == 0)
    return {};

  // .rela.toc contains exclusively R_PPC64_ADDR64 relocations sorted by
  // r_offset: 0, 8, 16, etc. For a given Offset, Offset / 8 gives us the
  // relocation index in most cases.
  //
  // In rare cases a TOC entry may store a constant that doesn't need an
  // R_PPC64_ADDR64, the corresponding r_offset is therefore missing. Offset / 8
  // points to a relocation with larger r_offset. Do a linear probe then.
  // Constants are extremely uncommon in .toc and the extra number of array
  // accesses can be seen as a small constant.
  ArrayRef<typename ELFT::Rela> relas = tocSec->template relas<ELFT>();
  uint64_t index = std::min<uint64_t>(offset / 8, relas.size() - 1);
  for (;;) {
    if (relas[index].r_offset == offset) {
      Symbol &sym = tocSec->getFile<ELFT>()->getRelocTargetSym(relas[index]);
      return {dyn_cast<Defined>(&sym), getAddend<ELFT>(relas[index])};
    }
    if (relas[index].r_offset < offset || index == 0)
      break;
    --index;
  }
  return {};
}

// When accessing a symbol defined in another translation unit, compilers
// reserve a .toc entry, allocate a local label and generate toc-indirect
// instuctions:
//
//   addis 3, 2, .LC0@toc@ha  # R_PPC64_TOC16_HA
//   ld    3, .LC0@toc@l(3)   # R_PPC64_TOC16_LO_DS, load the address from a .toc entry
//   ld/lwa 3, 0(3)           # load the value from the address
//
//   .section .toc,"aw",@progbits
//   .LC0: .tc var[TC],var
//
// If var is defined, non-preemptable and addressable with a 32-bit signed
// offset from the toc base, the address of var can be computed by adding an
// offset to the toc base, saving a load.
//
//   addis 3,2,var@toc@ha     # this may be relaxed to a nop,
//   addi  3,3,var@toc@l      # then this becomes addi 3,2,var@toc
//   ld/lwa 3, 0(3)           # load the value from the address
//
// Returns true if the relaxation is performed.
bool elf::tryRelaxPPC64TocIndirection(RelType type, const Relocation &rel,
                                      uint8_t *bufLoc) {
  assert(config->tocOptimize);
  if (rel.addend < 0)
    return false;

  // If the symbol is not the .toc section, this isn't a toc-indirection.
  Defined *defSym = dyn_cast<Defined>(rel.sym);
  if (!defSym || !defSym->isSection() || defSym->section->name != ".toc")
    return false;

  Defined *d;
  int64_t addend;
  auto *tocISB = cast<InputSectionBase>(defSym->section);
  std::tie(d, addend) =
      config->isLE ? getRelaTocSymAndAddend<ELF64LE>(tocISB, rel.addend)
                   : getRelaTocSymAndAddend<ELF64BE>(tocISB, rel.addend);

  // Only non-preemptable defined symbols can be relaxed.
  if (!d || d->isPreemptible)
    return false;

  // Two instructions can materialize a 32-bit signed offset from the toc base.
  uint64_t tocRelative = d->getVA(addend) - getPPC64TocBase();
  if (!isInt<32>(tocRelative))
    return false;

  // Add PPC64TocOffset that will be subtracted by relocateOne().
  target->relaxGot(bufLoc, type, tocRelative + ppc64TocOffset);
  return true;
}

namespace {
class PPC64 final : public TargetInfo {
public:
  PPC64();
  int getTlsGdRelaxSkip(RelType type) const override;
  uint32_t calcEFlags() const override;
  RelExpr getRelExpr(RelType type, const Symbol &s,
                     const uint8_t *loc) const override;
  RelType getDynRel(RelType type) const override;
  void writePltHeader(uint8_t *buf) const override;
  void writePlt(uint8_t *buf, uint64_t gotPltEntryAddr, uint64_t pltEntryAddr,
                int32_t index, unsigned relOff) const override;
  void relocateOne(uint8_t *loc, RelType type, uint64_t val) const override;
  void writeGotHeader(uint8_t *buf) const override;
  bool needsThunk(RelExpr expr, RelType type, const InputFile *file,
                  uint64_t branchAddr, const Symbol &s) const override;
  uint32_t getThunkSectionSpacing() const override;
  bool inBranchRange(RelType type, uint64_t src, uint64_t dst) const override;
  RelExpr adjustRelaxExpr(RelType type, const uint8_t *data,
                          RelExpr expr) const override;
  void relaxGot(uint8_t *loc, RelType type, uint64_t val) const override;
  void relaxTlsGdToIe(uint8_t *loc, RelType type, uint64_t val) const override;
  void relaxTlsGdToLe(uint8_t *loc, RelType type, uint64_t val) const override;
  void relaxTlsLdToLe(uint8_t *loc, RelType type, uint64_t val) const override;
  void relaxTlsIeToLe(uint8_t *loc, RelType type, uint64_t val) const override;

  bool adjustPrologueForCrossSplitStack(uint8_t *loc, uint8_t *end,
                                        uint8_t stOther) const override;
};
} // namespace

// Relocation masks following the #lo(value), #hi(value), #ha(value),
// #higher(value), #highera(value), #highest(value), and #highesta(value)
// macros defined in section 4.5.1. Relocation Types of the PPC-elf64abi
// document.
static uint16_t lo(uint64_t v) { return v; }
static uint16_t hi(uint64_t v) { return v >> 16; }
static uint16_t ha(uint64_t v) { return (v + 0x8000) >> 16; }
static uint16_t higher(uint64_t v) { return v >> 32; }
static uint16_t highera(uint64_t v) { return (v + 0x8000) >> 32; }
static uint16_t highest(uint64_t v) { return v >> 48; }
static uint16_t highesta(uint64_t v) { return (v + 0x8000) >> 48; }

// Extracts the 'PO' field of an instruction encoding.
static uint8_t getPrimaryOpCode(uint32_t encoding) { return (encoding >> 26); }

static bool isDQFormInstruction(uint32_t encoding) {
  switch (getPrimaryOpCode(encoding)) {
  default:
    return false;
  case 56:
    // The only instruction with a primary opcode of 56 is `lq`.
    return true;
  case 61:
    // There are both DS and DQ instruction forms with this primary opcode.
    // Namely `lxv` and `stxv` are the DQ-forms that use it.
    // The DS 'XO' bits being set to 01 is restricted to DQ form.
    return (encoding & 3) == 0x1;
  }
}

static bool isInstructionUpdateForm(uint32_t encoding) {
  switch (getPrimaryOpCode(encoding)) {
  default:
    return false;
  case LBZU:
  case LHAU:
  case LHZU:
  case LWZU:
  case LFSU:
  case LFDU:
  case STBU:
  case STHU:
  case STWU:
  case STFSU:
  case STFDU:
    return true;
    // LWA has the same opcode as LD, and the DS bits is what differentiates
    // between LD/LDU/LWA
  case LD:
  case STD:
    return (encoding & 3) == 1;
  }
}

// There are a number of places when we either want to read or write an
// instruction when handling a half16 relocation type. On big-endian the buffer
// pointer is pointing into the middle of the word we want to extract, and on
// little-endian it is pointing to the start of the word. These 2 helpers are to
// simplify reading and writing in that context.
static void writeFromHalf16(uint8_t *loc, uint32_t insn) {
  write32(config->isLE ? loc : loc - 2, insn);
}

static uint32_t readFromHalf16(const uint8_t *loc) {
  return read32(config->isLE ? loc : loc - 2);
}

PPC64::PPC64() {
  gotRel = R_PPC64_GLOB_DAT;
  noneRel = R_PPC64_NONE;
  pltRel = R_PPC64_JMP_SLOT;
  relativeRel = R_PPC64_RELATIVE;
  iRelativeRel = R_PPC64_IRELATIVE;
  symbolicRel = R_PPC64_ADDR64;
  pltEntrySize = 4;
  gotBaseSymInGotPlt = false;
  gotHeaderEntriesNum = 1;
  gotPltHeaderEntriesNum = 2;
  pltHeaderSize = 60;
  needsThunks = true;

  tlsModuleIndexRel = R_PPC64_DTPMOD64;
  tlsOffsetRel = R_PPC64_DTPREL64;

  tlsGotRel = R_PPC64_TPREL64;

  needsMoreStackNonSplit = false;

  // We need 64K pages (at least under glibc/Linux, the loader won't
  // set different permissions on a finer granularity than that).
  defaultMaxPageSize = 65536;

  // The PPC64 ELF ABI v1 spec, says:
  //
  //   It is normally desirable to put segments with different characteristics
  //   in separate 256 Mbyte portions of the address space, to give the
  //   operating system full paging flexibility in the 64-bit address space.
  //
  // And because the lowest non-zero 256M boundary is 0x10000000, PPC64 linkers
  // use 0x10000000 as the starting address.
  defaultImageBase = 0x10000000;

  write32(trapInstr.data(), 0x7fe00008);
}

int PPC64::getTlsGdRelaxSkip(RelType type) const {
  // A __tls_get_addr call instruction is marked with 2 relocations:
  //
  //   R_PPC64_TLSGD / R_PPC64_TLSLD: marker relocation
  //   R_PPC64_REL24: __tls_get_addr
  //
  // After the relaxation we no longer call __tls_get_addr and should skip both
  // relocations to not create a false dependence on __tls_get_addr being
  // defined.
  if (type == R_PPC64_TLSGD || type == R_PPC64_TLSLD)
    return 2;
  return 1;
}

static uint32_t getEFlags(InputFile *file) {
  if (config->ekind == ELF64BEKind)
    return cast<ObjFile<ELF64BE>>(file)->getObj().getHeader()->e_flags;
  return cast<ObjFile<ELF64LE>>(file)->getObj().getHeader()->e_flags;
}

// This file implements v2 ABI. This function makes sure that all
// object files have v2 or an unspecified version as an ABI version.
uint32_t PPC64::calcEFlags() const {
  for (InputFile *f : objectFiles) {
    uint32_t flag = getEFlags(f);
    if (flag == 1)
      error(toString(f) + ": ABI version 1 is not supported");
    else if (flag > 2)
      error(toString(f) + ": unrecognized e_flags: " + Twine(flag));
  }
  return 2;
}

void PPC64::relaxGot(uint8_t *loc, RelType type, uint64_t val) const {
  switch (type) {
  case R_PPC64_TOC16_HA:
    // Convert "addis reg, 2, .LC0@toc@h" to "addis reg, 2, var@toc@h" or "nop".
    relocateOne(loc, type, val);
    break;
  case R_PPC64_TOC16_LO_DS: {
    // Convert "ld reg, .LC0@toc@l(reg)" to "addi reg, reg, var@toc@l" or
    // "addi reg, 2, var@toc".
    uint32_t insn = readFromHalf16(loc);
    if (getPrimaryOpCode(insn) != LD)
      error("expected a 'ld' for got-indirect to toc-relative relaxing");
    writeFromHalf16(loc, (insn & 0x03ffffff) | 0x38000000);
    relocateOne(loc, R_PPC64_TOC16_LO, val);
    break;
  }
  default:
    llvm_unreachable("unexpected relocation type");
  }
}

void PPC64::relaxTlsGdToLe(uint8_t *loc, RelType type, uint64_t val) const {
  // Reference: 3.7.4.2 of the 64-bit ELF V2 abi supplement.
  // The general dynamic code sequence for a global `x` will look like:
  // Instruction                    Relocation                Symbol
  // addis r3, r2, x@got@tlsgd@ha   R_PPC64_GOT_TLSGD16_HA      x
  // addi  r3, r3, x@got@tlsgd@l    R_PPC64_GOT_TLSGD16_LO      x
  // bl __tls_get_addr(x@tlsgd)     R_PPC64_TLSGD               x
  //                                R_PPC64_REL24               __tls_get_addr
  // nop                            None                       None

  // Relaxing to local exec entails converting:
  // addis r3, r2, x@got@tlsgd@ha    into      nop
  // addi  r3, r3, x@got@tlsgd@l     into      addis r3, r13, x@tprel@ha
  // bl __tls_get_addr(x@tlsgd)      into      nop
  // nop                             into      addi r3, r3, x@tprel@l

  switch (type) {
  case R_PPC64_GOT_TLSGD16_HA:
    writeFromHalf16(loc, 0x60000000); // nop
    break;
  case R_PPC64_GOT_TLSGD16:
  case R_PPC64_GOT_TLSGD16_LO:
    writeFromHalf16(loc, 0x3c6d0000); // addis r3, r13
    relocateOne(loc, R_PPC64_TPREL16_HA, val);
    break;
  case R_PPC64_TLSGD:
    write32(loc, 0x60000000);     // nop
    write32(loc + 4, 0x38630000); // addi r3, r3
    // Since we are relocating a half16 type relocation and Loc + 4 points to
    // the start of an instruction we need to advance the buffer by an extra
    // 2 bytes on BE.
    relocateOne(loc + 4 + (config->ekind == ELF64BEKind ? 2 : 0),
                R_PPC64_TPREL16_LO, val);
    break;
  default:
    llvm_unreachable("unsupported relocation for TLS GD to LE relaxation");
  }
}

void PPC64::relaxTlsLdToLe(uint8_t *loc, RelType type, uint64_t val) const {
  // Reference: 3.7.4.3 of the 64-bit ELF V2 abi supplement.
  // The local dynamic code sequence for a global `x` will look like:
  // Instruction                    Relocation                Symbol
  // addis r3, r2, x@got@tlsld@ha   R_PPC64_GOT_TLSLD16_HA      x
  // addi  r3, r3, x@got@tlsld@l    R_PPC64_GOT_TLSLD16_LO      x
  // bl __tls_get_addr(x@tlsgd)     R_PPC64_TLSLD               x
  //                                R_PPC64_REL24               __tls_get_addr
  // nop                            None                       None

  // Relaxing to local exec entails converting:
  // addis r3, r2, x@got@tlsld@ha   into      nop
  // addi  r3, r3, x@got@tlsld@l    into      addis r3, r13, 0
  // bl __tls_get_addr(x@tlsgd)     into      nop
  // nop                            into      addi r3, r3, 4096

  switch (type) {
  case R_PPC64_GOT_TLSLD16_HA:
    writeFromHalf16(loc, 0x60000000); // nop
    break;
  case R_PPC64_GOT_TLSLD16_LO:
    writeFromHalf16(loc, 0x3c6d0000); // addis r3, r13, 0
    break;
  case R_PPC64_TLSLD:
    write32(loc, 0x60000000);     // nop
    write32(loc + 4, 0x38631000); // addi r3, r3, 4096
    break;
  case R_PPC64_DTPREL16:
  case R_PPC64_DTPREL16_HA:
  case R_PPC64_DTPREL16_HI:
  case R_PPC64_DTPREL16_DS:
  case R_PPC64_DTPREL16_LO:
  case R_PPC64_DTPREL16_LO_DS:
    relocateOne(loc, type, val);
    break;
  default:
    llvm_unreachable("unsupported relocation for TLS LD to LE relaxation");
  }
}

unsigned elf::getPPCDFormOp(unsigned secondaryOp) {
  switch (secondaryOp) {
  case LBZX:
    return LBZ;
  case LHZX:
    return LHZ;
  case LWZX:
    return LWZ;
  case LDX:
    return LD;
  case STBX:
    return STB;
  case STHX:
    return STH;
  case STWX:
    return STW;
  case STDX:
    return STD;
  case ADD:
    return ADDI;
  default:
    return 0;
  }
}

void PPC64::relaxTlsIeToLe(uint8_t *loc, RelType type, uint64_t val) const {
  // The initial exec code sequence for a global `x` will look like:
  // Instruction                    Relocation                Symbol
  // addis r9, r2, x@got@tprel@ha   R_PPC64_GOT_TPREL16_HA      x
  // ld    r9, x@got@tprel@l(r9)    R_PPC64_GOT_TPREL16_LO_DS   x
  // add r9, r9, x@tls              R_PPC64_TLS                 x

  // Relaxing to local exec entails converting:
  // addis r9, r2, x@got@tprel@ha       into        nop
  // ld r9, x@got@tprel@l(r9)           into        addis r9, r13, x@tprel@ha
  // add r9, r9, x@tls                  into        addi r9, r9, x@tprel@l

  // x@tls R_PPC64_TLS is a relocation which does not compute anything,
  // it is replaced with r13 (thread pointer).

  // The add instruction in the initial exec sequence has multiple variations
  // that need to be handled. If we are building an address it will use an add
  // instruction, if we are accessing memory it will use any of the X-form
  // indexed load or store instructions.

  unsigned offset = (config->ekind == ELF64BEKind) ? 2 : 0;
  switch (type) {
  case R_PPC64_GOT_TPREL16_HA:
    write32(loc - offset, 0x60000000); // nop
    break;
  case R_PPC64_GOT_TPREL16_LO_DS:
  case R_PPC64_GOT_TPREL16_DS: {
    uint32_t regNo = read32(loc - offset) & 0x03E00000; // bits 6-10
    write32(loc - offset, 0x3C0D0000 | regNo);          // addis RegNo, r13
    relocateOne(loc, R_PPC64_TPREL16_HA, val);
    break;
  }
  case R_PPC64_TLS: {
    uint32_t primaryOp = getPrimaryOpCode(read32(loc));
    if (primaryOp != 31)
      error("unrecognized instruction for IE to LE R_PPC64_TLS");
    uint32_t secondaryOp = (read32(loc) & 0x000007FE) >> 1; // bits 21-30
    uint32_t dFormOp = getPPCDFormOp(secondaryOp);
    if (dFormOp == 0)
      error("unrecognized instruction for IE to LE R_PPC64_TLS");
    write32(loc, ((dFormOp << 26) | (read32(loc) & 0x03FFFFFF)));
    relocateOne(loc + offset, R_PPC64_TPREL16_LO, val);
    break;
  }
  default:
    llvm_unreachable("unknown relocation for IE to LE");
    break;
  }
}

RelExpr PPC64::getRelExpr(RelType type, const Symbol &s,
                          const uint8_t *loc) const {
  switch (type) {
  case R_PPC64_NONE:
    return R_NONE;
  case R_PPC64_ADDR16:
  case R_PPC64_ADDR16_DS:
  case R_PPC64_ADDR16_HA:
  case R_PPC64_ADDR16_HI:
  case R_PPC64_ADDR16_HIGHER:
  case R_PPC64_ADDR16_HIGHERA:
  case R_PPC64_ADDR16_HIGHEST:
  case R_PPC64_ADDR16_HIGHESTA:
  case R_PPC64_ADDR16_LO:
  case R_PPC64_ADDR16_LO_DS:
  case R_PPC64_ADDR32:
  case R_PPC64_ADDR64:
    return R_ABS;
  case R_PPC64_GOT16:
  case R_PPC64_GOT16_DS:
  case R_PPC64_GOT16_HA:
  case R_PPC64_GOT16_HI:
  case R_PPC64_GOT16_LO:
  case R_PPC64_GOT16_LO_DS:
    return R_GOT_OFF;
  case R_PPC64_TOC16:
  case R_PPC64_TOC16_DS:
  case R_PPC64_TOC16_HI:
  case R_PPC64_TOC16_LO:
    return R_GOTREL;
  case R_PPC64_TOC16_HA:
  case R_PPC64_TOC16_LO_DS:
    return config->tocOptimize ? R_PPC64_RELAX_TOC : R_GOTREL;
  case R_PPC64_TOC:
    return R_PPC64_TOCBASE;
  case R_PPC64_REL14:
  case R_PPC64_REL24:
    return R_PPC64_CALL_PLT;
  case R_PPC64_REL16_LO:
  case R_PPC64_REL16_HA:
  case R_PPC64_REL16_HI:
  case R_PPC64_REL32:
  case R_PPC64_REL64:
    return R_PC;
  case R_PPC64_GOT_TLSGD16:
  case R_PPC64_GOT_TLSGD16_HA:
  case R_PPC64_GOT_TLSGD16_HI:
  case R_PPC64_GOT_TLSGD16_LO:
    return R_TLSGD_GOT;
  case R_PPC64_GOT_TLSLD16:
  case R_PPC64_GOT_TLSLD16_HA:
  case R_PPC64_GOT_TLSLD16_HI:
  case R_PPC64_GOT_TLSLD16_LO:
    return R_TLSLD_GOT;
  case R_PPC64_GOT_TPREL16_HA:
  case R_PPC64_GOT_TPREL16_LO_DS:
  case R_PPC64_GOT_TPREL16_DS:
  case R_PPC64_GOT_TPREL16_HI:
    return R_GOT_OFF;
  case R_PPC64_GOT_DTPREL16_HA:
  case R_PPC64_GOT_DTPREL16_LO_DS:
  case R_PPC64_GOT_DTPREL16_DS:
  case R_PPC64_GOT_DTPREL16_HI:
    return R_TLSLD_GOT_OFF;
  case R_PPC64_TPREL16:
  case R_PPC64_TPREL16_HA:
  case R_PPC64_TPREL16_LO:
  case R_PPC64_TPREL16_HI:
  case R_PPC64_TPREL16_DS:
  case R_PPC64_TPREL16_LO_DS:
  case R_PPC64_TPREL16_HIGHER:
  case R_PPC64_TPREL16_HIGHERA:
  case R_PPC64_TPREL16_HIGHEST:
  case R_PPC64_TPREL16_HIGHESTA:
    return R_TLS;
  case R_PPC64_DTPREL16:
  case R_PPC64_DTPREL16_DS:
  case R_PPC64_DTPREL16_HA:
  case R_PPC64_DTPREL16_HI:
  case R_PPC64_DTPREL16_HIGHER:
  case R_PPC64_DTPREL16_HIGHERA:
  case R_PPC64_DTPREL16_HIGHEST:
  case R_PPC64_DTPREL16_HIGHESTA:
  case R_PPC64_DTPREL16_LO:
  case R_PPC64_DTPREL16_LO_DS:
  case R_PPC64_DTPREL64:
    return R_DTPREL;
  case R_PPC64_TLSGD:
    return R_TLSDESC_CALL;
  case R_PPC64_TLSLD:
    return R_TLSLD_HINT;
  case R_PPC64_TLS:
    return R_TLSIE_HINT;
  default:
    error(getErrorLocation(loc) + "unknown relocation (" + Twine(type) +
          ") against symbol " + toString(s));
    return R_NONE;
  }
}

RelType PPC64::getDynRel(RelType type) const {
  if (type == R_PPC64_ADDR64 || type == R_PPC64_TOC)
    return R_PPC64_ADDR64;
  return R_PPC64_NONE;
}

void PPC64::writeGotHeader(uint8_t *buf) const {
  write64(buf, getPPC64TocBase());
}

void PPC64::writePltHeader(uint8_t *buf) const {
  // The generic resolver stub goes first.
  write32(buf +  0, 0x7c0802a6); // mflr r0
  write32(buf +  4, 0x429f0005); // bcl  20,4*cr7+so,8 <_glink+0x8>
  write32(buf +  8, 0x7d6802a6); // mflr r11
  write32(buf + 12, 0x7c0803a6); // mtlr r0
  write32(buf + 16, 0x7d8b6050); // subf r12, r11, r12
  write32(buf + 20, 0x380cffcc); // subi r0,r12,52
  write32(buf + 24, 0x7800f082); // srdi r0,r0,62,2
  write32(buf + 28, 0xe98b002c); // ld   r12,44(r11)
  write32(buf + 32, 0x7d6c5a14); // add  r11,r12,r11
  write32(buf + 36, 0xe98b0000); // ld   r12,0(r11)
  write32(buf + 40, 0xe96b0008); // ld   r11,8(r11)
  write32(buf + 44, 0x7d8903a6); // mtctr   r12
  write32(buf + 48, 0x4e800420); // bctr

  // The 'bcl' instruction will set the link register to the address of the
  // following instruction ('mflr r11'). Here we store the offset from that
  // instruction  to the first entry in the GotPlt section.
  int64_t gotPltOffset = in.gotPlt->getVA() - (in.plt->getVA() + 8);
  write64(buf + 52, gotPltOffset);
}

void PPC64::writePlt(uint8_t *buf, uint64_t gotPltEntryAddr,
                     uint64_t pltEntryAddr, int32_t index,
                     unsigned relOff) const {
  int32_t offset = pltHeaderSize + index * pltEntrySize;
  // bl __glink_PLTresolve
  write32(buf, 0x48000000 | ((-offset) & 0x03FFFFFc));
}

static std::pair<RelType, uint64_t> toAddr16Rel(RelType type, uint64_t val) {
  // Relocations relative to the toc-base need to be adjusted by the Toc offset.
  uint64_t tocBiasedVal = val - ppc64TocOffset;
  // Relocations relative to dtv[dtpmod] need to be adjusted by the DTP offset.
  uint64_t dtpBiasedVal = val - dynamicThreadPointerOffset;

  switch (type) {
  // TOC biased relocation.
  case R_PPC64_GOT16:
  case R_PPC64_GOT_TLSGD16:
  case R_PPC64_GOT_TLSLD16:
  case R_PPC64_TOC16:
    return {R_PPC64_ADDR16, tocBiasedVal};
  case R_PPC64_GOT16_DS:
  case R_PPC64_TOC16_DS:
  case R_PPC64_GOT_TPREL16_DS:
  case R_PPC64_GOT_DTPREL16_DS:
    return {R_PPC64_ADDR16_DS, tocBiasedVal};
  case R_PPC64_GOT16_HA:
  case R_PPC64_GOT_TLSGD16_HA:
  case R_PPC64_GOT_TLSLD16_HA:
  case R_PPC64_GOT_TPREL16_HA:
  case R_PPC64_GOT_DTPREL16_HA:
  case R_PPC64_TOC16_HA:
    return {R_PPC64_ADDR16_HA, tocBiasedVal};
  case R_PPC64_GOT16_HI:
  case R_PPC64_GOT_TLSGD16_HI:
  case R_PPC64_GOT_TLSLD16_HI:
  case R_PPC64_GOT_TPREL16_HI:
  case R_PPC64_GOT_DTPREL16_HI:
  case R_PPC64_TOC16_HI:
    return {R_PPC64_ADDR16_HI, tocBiasedVal};
  case R_PPC64_GOT16_LO:
  case R_PPC64_GOT_TLSGD16_LO:
  case R_PPC64_GOT_TLSLD16_LO:
  case R_PPC64_TOC16_LO:
    return {R_PPC64_ADDR16_LO, tocBiasedVal};
  case R_PPC64_GOT16_LO_DS:
  case R_PPC64_TOC16_LO_DS:
  case R_PPC64_GOT_TPREL16_LO_DS:
  case R_PPC64_GOT_DTPREL16_LO_DS:
    return {R_PPC64_ADDR16_LO_DS, tocBiasedVal};

  // Dynamic Thread pointer biased relocation types.
  case R_PPC64_DTPREL16:
    return {R_PPC64_ADDR16, dtpBiasedVal};
  case R_PPC64_DTPREL16_DS:
    return {R_PPC64_ADDR16_DS, dtpBiasedVal};
  case R_PPC64_DTPREL16_HA:
    return {R_PPC64_ADDR16_HA, dtpBiasedVal};
  case R_PPC64_DTPREL16_HI:
    return {R_PPC64_ADDR16_HI, dtpBiasedVal};
  case R_PPC64_DTPREL16_HIGHER:
    return {R_PPC64_ADDR16_HIGHER, dtpBiasedVal};
  case R_PPC64_DTPREL16_HIGHERA:
    return {R_PPC64_ADDR16_HIGHERA, dtpBiasedVal};
  case R_PPC64_DTPREL16_HIGHEST:
    return {R_PPC64_ADDR16_HIGHEST, dtpBiasedVal};
  case R_PPC64_DTPREL16_HIGHESTA:
    return {R_PPC64_ADDR16_HIGHESTA, dtpBiasedVal};
  case R_PPC64_DTPREL16_LO:
    return {R_PPC64_ADDR16_LO, dtpBiasedVal};
  case R_PPC64_DTPREL16_LO_DS:
    return {R_PPC64_ADDR16_LO_DS, dtpBiasedVal};
  case R_PPC64_DTPREL64:
    return {R_PPC64_ADDR64, dtpBiasedVal};

  default:
    return {type, val};
  }
}

static bool isTocOptType(RelType type) {
  switch (type) {
  case R_PPC64_GOT16_HA:
  case R_PPC64_GOT16_LO_DS:
  case R_PPC64_TOC16_HA:
  case R_PPC64_TOC16_LO_DS:
  case R_PPC64_TOC16_LO:
    return true;
  default:
    return false;
  }
}

void PPC64::relocateOne(uint8_t *loc, RelType type, uint64_t val) const {
  // We need to save the original relocation type to use in diagnostics, and
  // use the original type to determine if we should toc-optimize the
  // instructions being relocated.
  RelType originalType = type;
  bool shouldTocOptimize =  isTocOptType(type);
  // For dynamic thread pointer relative, toc-relative, and got-indirect
  // relocations, proceed in terms of the corresponding ADDR16 relocation type.
  std::tie(type, val) = toAddr16Rel(type, val);

  switch (type) {
  case R_PPC64_ADDR14: {
    checkAlignment(loc, val, 4, type);
    // Preserve the AA/LK bits in the branch instruction
    uint8_t aalk = loc[3];
    write16(loc + 2, (aalk & 3) | (val & 0xfffc));
    break;
  }
  case R_PPC64_ADDR16:
    checkIntUInt(loc, val, 16, originalType);
    write16(loc, val);
    break;
  case R_PPC64_ADDR32:
    checkIntUInt(loc, val, 32, originalType);
    write32(loc, val);
    break;
  case R_PPC64_ADDR16_DS:
  case R_PPC64_TPREL16_DS: {
    checkInt(loc, val, 16, originalType);
    // DQ-form instructions use bits 28-31 as part of the instruction encoding
    // DS-form instructions only use bits 30-31.
    uint16_t mask = isDQFormInstruction(readFromHalf16(loc)) ? 0xf : 0x3;
    checkAlignment(loc, lo(val), mask + 1, originalType);
    write16(loc, (read16(loc) & mask) | lo(val));
  } break;
  case R_PPC64_ADDR16_HA:
  case R_PPC64_REL16_HA:
  case R_PPC64_TPREL16_HA:
    if (config->tocOptimize && shouldTocOptimize && ha(val) == 0)
      writeFromHalf16(loc, 0x60000000);
    else
      write16(loc, ha(val));
    break;
  case R_PPC64_ADDR16_HI:
  case R_PPC64_REL16_HI:
  case R_PPC64_TPREL16_HI:
    write16(loc, hi(val));
    break;
  case R_PPC64_ADDR16_HIGHER:
  case R_PPC64_TPREL16_HIGHER:
    write16(loc, higher(val));
    break;
  case R_PPC64_ADDR16_HIGHERA:
  case R_PPC64_TPREL16_HIGHERA:
    write16(loc, highera(val));
    break;
  case R_PPC64_ADDR16_HIGHEST:
  case R_PPC64_TPREL16_HIGHEST:
    write16(loc, highest(val));
    break;
  case R_PPC64_ADDR16_HIGHESTA:
  case R_PPC64_TPREL16_HIGHESTA:
    write16(loc, highesta(val));
    break;
  case R_PPC64_ADDR16_LO:
  case R_PPC64_REL16_LO:
  case R_PPC64_TPREL16_LO:
    // When the high-adjusted part of a toc relocation evalutes to 0, it is
    // changed into a nop. The lo part then needs to be updated to use the
    // toc-pointer register r2, as the base register.
    if (config->tocOptimize && shouldTocOptimize && ha(val) == 0) {
      uint32_t insn = readFromHalf16(loc);
      if (isInstructionUpdateForm(insn))
        error(getErrorLocation(loc) +
              "can't toc-optimize an update instruction: 0x" +
              utohexstr(insn));
      writeFromHalf16(loc, (insn & 0xffe00000) | 0x00020000 | lo(val));
    } else {
      write16(loc, lo(val));
    }
    break;
  case R_PPC64_ADDR16_LO_DS:
  case R_PPC64_TPREL16_LO_DS: {
    // DQ-form instructions use bits 28-31 as part of the instruction encoding
    // DS-form instructions only use bits 30-31.
    uint32_t insn = readFromHalf16(loc);
    uint16_t mask = isDQFormInstruction(insn) ? 0xf : 0x3;
    checkAlignment(loc, lo(val), mask + 1, originalType);
    if (config->tocOptimize && shouldTocOptimize && ha(val) == 0) {
      // When the high-adjusted part of a toc relocation evalutes to 0, it is
      // changed into a nop. The lo part then needs to be updated to use the toc
      // pointer register r2, as the base register.
      if (isInstructionUpdateForm(insn))
        error(getErrorLocation(loc) +
              "Can't toc-optimize an update instruction: 0x" +
              Twine::utohexstr(insn));
      insn &= 0xffe00000 | mask;
      writeFromHalf16(loc, insn | 0x00020000 | lo(val));
    } else {
      write16(loc, (read16(loc) & mask) | lo(val));
    }
  } break;
  case R_PPC64_TPREL16:
    checkInt(loc, val, 16, originalType);
    write16(loc, val);
    break;
  case R_PPC64_REL32:
    checkInt(loc, val, 32, type);
    write32(loc, val);
    break;
  case R_PPC64_ADDR64:
  case R_PPC64_REL64:
  case R_PPC64_TOC:
    write64(loc, val);
    break;
  case R_PPC64_REL14: {
    uint32_t mask = 0x0000FFFC;
    checkInt(loc, val, 16, type);
    checkAlignment(loc, val, 4, type);
    write32(loc, (read32(loc) & ~mask) | (val & mask));
    break;
  }
  case R_PPC64_REL24: {
    uint32_t mask = 0x03FFFFFC;
    checkInt(loc, val, 26, type);
    checkAlignment(loc, val, 4, type);
    write32(loc, (read32(loc) & ~mask) | (val & mask));
    break;
  }
  case R_PPC64_DTPREL64:
    write64(loc, val - dynamicThreadPointerOffset);
    break;
  default:
    llvm_unreachable("unknown relocation");
  }
}

bool PPC64::needsThunk(RelExpr expr, RelType type, const InputFile *file,
                       uint64_t branchAddr, const Symbol &s) const {
  if (type != R_PPC64_REL14 && type != R_PPC64_REL24)
    return false;

  // If a function is in the Plt it needs to be called with a call-stub.
  if (s.isInPlt())
    return true;

  // If a symbol is a weak undefined and we are compiling an executable
  // it doesn't need a range-extending thunk since it can't be called.
  if (s.isUndefWeak() && !config->shared)
    return false;

  // If the offset exceeds the range of the branch type then it will need
  // a range-extending thunk.
  // See the comment in getRelocTargetVA() about R_PPC64_CALL.
  return !inBranchRange(type, branchAddr,
                        s.getVA() +
                            getPPC64GlobalEntryToLocalEntryOffset(s.stOther));
}

uint32_t PPC64::getThunkSectionSpacing() const {
  // See comment in Arch/ARM.cpp for a more detailed explanation of
  // getThunkSectionSpacing(). For PPC64 we pick the constant here based on
  // R_PPC64_REL24, which is used by unconditional branch instructions.
  // 0x2000000 = (1 << 24-1) * 4
  return 0x2000000;
}

bool PPC64::inBranchRange(RelType type, uint64_t src, uint64_t dst) const {
  int64_t offset = dst - src;
  if (type == R_PPC64_REL14)
    return isInt<16>(offset);
  if (type == R_PPC64_REL24)
    return isInt<26>(offset);
  llvm_unreachable("unsupported relocation type used in branch");
}

RelExpr PPC64::adjustRelaxExpr(RelType type, const uint8_t *data,
                               RelExpr expr) const {
  if (expr == R_RELAX_TLS_GD_TO_IE)
    return R_RELAX_TLS_GD_TO_IE_GOT_OFF;
  if (expr == R_RELAX_TLS_LD_TO_LE)
    return R_RELAX_TLS_LD_TO_LE_ABS;
  return expr;
}

// Reference: 3.7.4.1 of the 64-bit ELF V2 abi supplement.
// The general dynamic code sequence for a global `x` uses 4 instructions.
// Instruction                    Relocation                Symbol
// addis r3, r2, x@got@tlsgd@ha   R_PPC64_GOT_TLSGD16_HA      x
// addi  r3, r3, x@got@tlsgd@l    R_PPC64_GOT_TLSGD16_LO      x
// bl __tls_get_addr(x@tlsgd)     R_PPC64_TLSGD               x
//                                R_PPC64_REL24               __tls_get_addr
// nop                            None                       None
//
// Relaxing to initial-exec entails:
// 1) Convert the addis/addi pair that builds the address of the tls_index
//    struct for 'x' to an addis/ld pair that loads an offset from a got-entry.
// 2) Convert the call to __tls_get_addr to a nop.
// 3) Convert the nop following the call to an add of the loaded offset to the
//    thread pointer.
// Since the nop must directly follow the call, the R_PPC64_TLSGD relocation is
// used as the relaxation hint for both steps 2 and 3.
void PPC64::relaxTlsGdToIe(uint8_t *loc, RelType type, uint64_t val) const {
  switch (type) {
  case R_PPC64_GOT_TLSGD16_HA:
    // This is relaxed from addis rT, r2, sym@got@tlsgd@ha to
    //                      addis rT, r2, sym@got@tprel@ha.
    relocateOne(loc, R_PPC64_GOT_TPREL16_HA, val);
    return;
  case R_PPC64_GOT_TLSGD16:
  case R_PPC64_GOT_TLSGD16_LO: {
    // Relax from addi  r3, rA, sym@got@tlsgd@l to
    //            ld r3, sym@got@tprel@l(rA)
    uint32_t ra = (readFromHalf16(loc) & (0x1f << 16));
    writeFromHalf16(loc, 0xe8600000 | ra);
    relocateOne(loc, R_PPC64_GOT_TPREL16_LO_DS, val);
    return;
  }
  case R_PPC64_TLSGD:
    write32(loc, 0x60000000);     // bl __tls_get_addr(sym@tlsgd) --> nop
    write32(loc + 4, 0x7c636A14); // nop --> add r3, r3, r13
    return;
  default:
    llvm_unreachable("unsupported relocation for TLS GD to IE relaxation");
  }
}

// The prologue for a split-stack function is expected to look roughly
// like this:
//    .Lglobal_entry_point:
//      # TOC pointer initalization.
//      ...
//    .Llocal_entry_point:
//      # load the __private_ss member of the threads tcbhead.
//      ld r0,-0x7000-64(r13)
//      # subtract the functions stack size from the stack pointer.
//      addis r12, r1, ha(-stack-frame size)
//      addi  r12, r12, l(-stack-frame size)
//      # compare needed to actual and branch to allocate_more_stack if more
//      # space is needed, otherwise fallthrough to 'normal' function body.
//      cmpld cr7,r12,r0
//      blt- cr7, .Lallocate_more_stack
//
// -) The allocate_more_stack block might be placed after the split-stack
//    prologue and the `blt-` replaced with a `bge+ .Lnormal_func_body`
//    instead.
// -) If either the addis or addi is not needed due to the stack size being
//    smaller then 32K or a multiple of 64K they will be replaced with a nop,
//    but there will always be 2 instructions the linker can overwrite for the
//    adjusted stack size.
//
// The linkers job here is to increase the stack size used in the addis/addi
// pair by split-stack-size-adjust.
// addis r12, r1, ha(-stack-frame size - split-stack-adjust-size)
// addi  r12, r12, l(-stack-frame size - split-stack-adjust-size)
bool PPC64::adjustPrologueForCrossSplitStack(uint8_t *loc, uint8_t *end,
                                             uint8_t stOther) const {
  // If the caller has a global entry point adjust the buffer past it. The start
  // of the split-stack prologue will be at the local entry point.
  loc += getPPC64GlobalEntryToLocalEntryOffset(stOther);

  // At the very least we expect to see a load of some split-stack data from the
  // tcb, and 2 instructions that calculate the ending stack address this
  // function will require. If there is not enough room for at least 3
  // instructions it can't be a split-stack prologue.
  if (loc + 12 >= end)
    return false;

  // First instruction must be `ld r0, -0x7000-64(r13)`
  if (read32(loc) != 0xe80d8fc0)
    return false;

  int16_t hiImm = 0;
  int16_t loImm = 0;
  // First instruction can be either an addis if the frame size is larger then
  // 32K, or an addi if the size is less then 32K.
  int32_t firstInstr = read32(loc + 4);
  if (getPrimaryOpCode(firstInstr) == 15) {
    hiImm = firstInstr & 0xFFFF;
  } else if (getPrimaryOpCode(firstInstr) == 14) {
    loImm = firstInstr & 0xFFFF;
  } else {
    return false;
  }

  // Second instruction is either an addi or a nop. If the first instruction was
  // an addi then LoImm is set and the second instruction must be a nop.
  uint32_t secondInstr = read32(loc + 8);
  if (!loImm && getPrimaryOpCode(secondInstr) == 14) {
    loImm = secondInstr & 0xFFFF;
  } else if (secondInstr != 0x60000000) {
    return false;
  }

  // The register operands of the first instruction should be the stack-pointer
  // (r1) as the input (RA) and r12 as the output (RT). If the second
  // instruction is not a nop, then it should use r12 as both input and output.
  auto checkRegOperands = [](uint32_t instr, uint8_t expectedRT,
                             uint8_t expectedRA) {
    return ((instr & 0x3E00000) >> 21 == expectedRT) &&
           ((instr & 0x1F0000) >> 16 == expectedRA);
  };
  if (!checkRegOperands(firstInstr, 12, 1))
    return false;
  if (secondInstr != 0x60000000 && !checkRegOperands(secondInstr, 12, 12))
    return false;

  int32_t stackFrameSize = (hiImm * 65536) + loImm;
  // Check that the adjusted size doesn't overflow what we can represent with 2
  // instructions.
  if (stackFrameSize < config->splitStackAdjustSize + INT32_MIN) {
    error(getErrorLocation(loc) + "split-stack prologue adjustment overflows");
    return false;
  }

  int32_t adjustedStackFrameSize =
      stackFrameSize - config->splitStackAdjustSize;

  loImm = adjustedStackFrameSize & 0xFFFF;
  hiImm = (adjustedStackFrameSize + 0x8000) >> 16;
  if (hiImm) {
    write32(loc + 4, 0x3D810000 | (uint16_t)hiImm);
    // If the low immediate is zero the second instruction will be a nop.
    secondInstr = loImm ? 0x398C0000 | (uint16_t)loImm : 0x60000000;
    write32(loc + 8, secondInstr);
  } else {
    // addi r12, r1, imm
    write32(loc + 4, (0x39810000) | (uint16_t)loImm);
    write32(loc + 8, 0x60000000);
  }

  return true;
}

TargetInfo *elf::getPPC64TargetInfo() {
  static PPC64 target;
  return &target;
}
