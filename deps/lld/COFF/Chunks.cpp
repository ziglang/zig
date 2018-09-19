//===- Chunks.cpp ---------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "Chunks.h"
#include "InputFiles.h"
#include "Symbols.h"
#include "Writer.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/ADT/Twine.h"
#include "llvm/BinaryFormat/COFF.h"
#include "llvm/Object/COFF.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/raw_ostream.h"
#include <algorithm>

using namespace llvm;
using namespace llvm::object;
using namespace llvm::support::endian;
using namespace llvm::COFF;
using llvm::support::ulittle32_t;

namespace lld {
namespace coff {

SectionChunk::SectionChunk(ObjFile *F, const coff_section *H)
    : Chunk(SectionKind), Repl(this), Header(H), File(F),
      Relocs(File->getCOFFObj()->getRelocations(Header)) {
  // Initialize SectionName.
  File->getCOFFObj()->getSectionName(Header, SectionName);

  Alignment = Header->getAlignment();

  // If linker GC is disabled, every chunk starts out alive.  If linker GC is
  // enabled, treat non-comdat sections as roots. Generally optimized object
  // files will be built with -ffunction-sections or /Gy, so most things worth
  // stripping will be in a comdat.
  Live = !Config->DoGC || !isCOMDAT();
}

static void add16(uint8_t *P, int16_t V) { write16le(P, read16le(P) + V); }
static void add32(uint8_t *P, int32_t V) { write32le(P, read32le(P) + V); }
static void add64(uint8_t *P, int64_t V) { write64le(P, read64le(P) + V); }
static void or16(uint8_t *P, uint16_t V) { write16le(P, read16le(P) | V); }
static void or32(uint8_t *P, uint32_t V) { write32le(P, read32le(P) | V); }

// Verify that given sections are appropriate targets for SECREL
// relocations. This check is relaxed because unfortunately debug
// sections have section-relative relocations against absolute symbols.
static bool checkSecRel(const SectionChunk *Sec, OutputSection *OS) {
  if (OS)
    return true;
  if (Sec->isCodeView())
    return false;
  fatal("SECREL relocation cannot be applied to absolute symbols");
}

static void applySecRel(const SectionChunk *Sec, uint8_t *Off,
                        OutputSection *OS, uint64_t S) {
  if (!checkSecRel(Sec, OS))
    return;
  uint64_t SecRel = S - OS->getRVA();
  if (SecRel > UINT32_MAX) {
    error("overflow in SECREL relocation in section: " + Sec->getSectionName());
    return;
  }
  add32(Off, SecRel);
}

static void applySecIdx(uint8_t *Off, OutputSection *OS) {
  // Absolute symbol doesn't have section index, but section index relocation
  // against absolute symbol should be resolved to one plus the last output
  // section index. This is required for compatibility with MSVC.
  if (OS)
    add16(Off, OS->SectionIndex);
  else
    add16(Off, DefinedAbsolute::NumOutputSections + 1);
}

void SectionChunk::applyRelX64(uint8_t *Off, uint16_t Type, OutputSection *OS,
                               uint64_t S, uint64_t P) const {
  switch (Type) {
  case IMAGE_REL_AMD64_ADDR32:   add32(Off, S + Config->ImageBase); break;
  case IMAGE_REL_AMD64_ADDR64:   add64(Off, S + Config->ImageBase); break;
  case IMAGE_REL_AMD64_ADDR32NB: add32(Off, S); break;
  case IMAGE_REL_AMD64_REL32:    add32(Off, S - P - 4); break;
  case IMAGE_REL_AMD64_REL32_1:  add32(Off, S - P - 5); break;
  case IMAGE_REL_AMD64_REL32_2:  add32(Off, S - P - 6); break;
  case IMAGE_REL_AMD64_REL32_3:  add32(Off, S - P - 7); break;
  case IMAGE_REL_AMD64_REL32_4:  add32(Off, S - P - 8); break;
  case IMAGE_REL_AMD64_REL32_5:  add32(Off, S - P - 9); break;
  case IMAGE_REL_AMD64_SECTION:  applySecIdx(Off, OS); break;
  case IMAGE_REL_AMD64_SECREL:   applySecRel(this, Off, OS, S); break;
  default:
    fatal("unsupported relocation type 0x" + Twine::utohexstr(Type) + " in " +
          toString(File));
  }
}

void SectionChunk::applyRelX86(uint8_t *Off, uint16_t Type, OutputSection *OS,
                               uint64_t S, uint64_t P) const {
  switch (Type) {
  case IMAGE_REL_I386_ABSOLUTE: break;
  case IMAGE_REL_I386_DIR32:    add32(Off, S + Config->ImageBase); break;
  case IMAGE_REL_I386_DIR32NB:  add32(Off, S); break;
  case IMAGE_REL_I386_REL32:    add32(Off, S - P - 4); break;
  case IMAGE_REL_I386_SECTION:  applySecIdx(Off, OS); break;
  case IMAGE_REL_I386_SECREL:   applySecRel(this, Off, OS, S); break;
  default:
    fatal("unsupported relocation type 0x" + Twine::utohexstr(Type) + " in " +
          toString(File));
  }
}

static void applyMOV(uint8_t *Off, uint16_t V) {
  write16le(Off, (read16le(Off) & 0xfbf0) | ((V & 0x800) >> 1) | ((V >> 12) & 0xf));
  write16le(Off + 2, (read16le(Off + 2) & 0x8f00) | ((V & 0x700) << 4) | (V & 0xff));
}

static uint16_t readMOV(uint8_t *Off) {
  uint16_t Op1 = read16le(Off);
  uint16_t Op2 = read16le(Off + 2);
  return (Op2 & 0x00ff) | ((Op2 >> 4) & 0x0700) | ((Op1 << 1) & 0x0800) |
         ((Op1 & 0x000f) << 12);
}

void applyMOV32T(uint8_t *Off, uint32_t V) {
  uint16_t ImmW = readMOV(Off);     // read MOVW operand
  uint16_t ImmT = readMOV(Off + 4); // read MOVT operand
  uint32_t Imm = ImmW | (ImmT << 16);
  V += Imm;                         // add the immediate offset
  applyMOV(Off, V);           // set MOVW operand
  applyMOV(Off + 4, V >> 16); // set MOVT operand
}

static void applyBranch20T(uint8_t *Off, int32_t V) {
  if (!isInt<21>(V))
    fatal("relocation out of range");
  uint32_t S = V < 0 ? 1 : 0;
  uint32_t J1 = (V >> 19) & 1;
  uint32_t J2 = (V >> 18) & 1;
  or16(Off, (S << 10) | ((V >> 12) & 0x3f));
  or16(Off + 2, (J1 << 13) | (J2 << 11) | ((V >> 1) & 0x7ff));
}

void applyBranch24T(uint8_t *Off, int32_t V) {
  if (!isInt<25>(V))
    fatal("relocation out of range");
  uint32_t S = V < 0 ? 1 : 0;
  uint32_t J1 = ((~V >> 23) & 1) ^ S;
  uint32_t J2 = ((~V >> 22) & 1) ^ S;
  or16(Off, (S << 10) | ((V >> 12) & 0x3ff));
  // Clear out the J1 and J2 bits which may be set.
  write16le(Off + 2, (read16le(Off + 2) & 0xd000) | (J1 << 13) | (J2 << 11) | ((V >> 1) & 0x7ff));
}

void SectionChunk::applyRelARM(uint8_t *Off, uint16_t Type, OutputSection *OS,
                               uint64_t S, uint64_t P) const {
  // Pointer to thumb code must have the LSB set.
  uint64_t SX = S;
  if (OS && (OS->Header.Characteristics & IMAGE_SCN_MEM_EXECUTE))
    SX |= 1;
  switch (Type) {
  case IMAGE_REL_ARM_ADDR32:    add32(Off, SX + Config->ImageBase); break;
  case IMAGE_REL_ARM_ADDR32NB:  add32(Off, SX); break;
  case IMAGE_REL_ARM_MOV32T:    applyMOV32T(Off, SX + Config->ImageBase); break;
  case IMAGE_REL_ARM_BRANCH20T: applyBranch20T(Off, SX - P - 4); break;
  case IMAGE_REL_ARM_BRANCH24T: applyBranch24T(Off, SX - P - 4); break;
  case IMAGE_REL_ARM_BLX23T:    applyBranch24T(Off, SX - P - 4); break;
  case IMAGE_REL_ARM_SECTION:   applySecIdx(Off, OS); break;
  case IMAGE_REL_ARM_SECREL:    applySecRel(this, Off, OS, S); break;
  default:
    fatal("unsupported relocation type 0x" + Twine::utohexstr(Type) + " in " +
          toString(File));
  }
}

// Interpret the existing immediate value as a byte offset to the
// target symbol, then update the instruction with the immediate as
// the page offset from the current instruction to the target.
static void applyArm64Addr(uint8_t *Off, uint64_t S, uint64_t P, int Shift) {
  uint32_t Orig = read32le(Off);
  uint64_t Imm = ((Orig >> 29) & 0x3) | ((Orig >> 3) & 0x1FFFFC);
  S += Imm;
  Imm = (S >> Shift) - (P >> Shift);
  uint32_t ImmLo = (Imm & 0x3) << 29;
  uint32_t ImmHi = (Imm & 0x1FFFFC) << 3;
  uint64_t Mask = (0x3 << 29) | (0x1FFFFC << 3);
  write32le(Off, (Orig & ~Mask) | ImmLo | ImmHi);
}

// Update the immediate field in a AARCH64 ldr, str, and add instruction.
// Optionally limit the range of the written immediate by one or more bits
// (RangeLimit).
static void applyArm64Imm(uint8_t *Off, uint64_t Imm, uint32_t RangeLimit) {
  uint32_t Orig = read32le(Off);
  Imm += (Orig >> 10) & 0xFFF;
  Orig &= ~(0xFFF << 10);
  write32le(Off, Orig | ((Imm & (0xFFF >> RangeLimit)) << 10));
}

// Add the 12 bit page offset to the existing immediate.
// Ldr/str instructions store the opcode immediate scaled
// by the load/store size (giving a larger range for larger
// loads/stores). The immediate is always (both before and after
// fixing up the relocation) stored scaled similarly.
// Even if larger loads/stores have a larger range, limit the
// effective offset to 12 bit, since it is intended to be a
// page offset.
static void applyArm64Ldr(uint8_t *Off, uint64_t Imm) {
  uint32_t Orig = read32le(Off);
  uint32_t Size = Orig >> 30;
  // 0x04000000 indicates SIMD/FP registers
  // 0x00800000 indicates 128 bit
  if ((Orig & 0x4800000) == 0x4800000)
    Size += 4;
  if ((Imm & ((1 << Size) - 1)) != 0)
    fatal("misaligned ldr/str offset");
  applyArm64Imm(Off, Imm >> Size, Size);
}

static void applySecRelLow12A(const SectionChunk *Sec, uint8_t *Off,
                              OutputSection *OS, uint64_t S) {
  if (checkSecRel(Sec, OS))
    applyArm64Imm(Off, (S - OS->getRVA()) & 0xfff, 0);
}

static void applySecRelHigh12A(const SectionChunk *Sec, uint8_t *Off,
                               OutputSection *OS, uint64_t S) {
  if (!checkSecRel(Sec, OS))
    return;
  uint64_t SecRel = (S - OS->getRVA()) >> 12;
  if (0xfff < SecRel) {
    error("overflow in SECREL_HIGH12A relocation in section: " +
          Sec->getSectionName());
    return;
  }
  applyArm64Imm(Off, SecRel & 0xfff, 0);
}

static void applySecRelLdr(const SectionChunk *Sec, uint8_t *Off,
                           OutputSection *OS, uint64_t S) {
  if (checkSecRel(Sec, OS))
    applyArm64Ldr(Off, (S - OS->getRVA()) & 0xfff);
}

static void applyArm64Branch26(uint8_t *Off, int64_t V) {
  if (!isInt<28>(V))
    fatal("relocation out of range");
  or32(Off, (V & 0x0FFFFFFC) >> 2);
}

static void applyArm64Branch19(uint8_t *Off, int64_t V) {
  if (!isInt<21>(V))
    fatal("relocation out of range");
  or32(Off, (V & 0x001FFFFC) << 3);
}

static void applyArm64Branch14(uint8_t *Off, int64_t V) {
  if (!isInt<16>(V))
    fatal("relocation out of range");
  or32(Off, (V & 0x0000FFFC) << 3);
}

void SectionChunk::applyRelARM64(uint8_t *Off, uint16_t Type, OutputSection *OS,
                                 uint64_t S, uint64_t P) const {
  switch (Type) {
  case IMAGE_REL_ARM64_PAGEBASE_REL21: applyArm64Addr(Off, S, P, 12); break;
  case IMAGE_REL_ARM64_REL21:          applyArm64Addr(Off, S, P, 0); break;
  case IMAGE_REL_ARM64_PAGEOFFSET_12A: applyArm64Imm(Off, S & 0xfff, 0); break;
  case IMAGE_REL_ARM64_PAGEOFFSET_12L: applyArm64Ldr(Off, S & 0xfff); break;
  case IMAGE_REL_ARM64_BRANCH26:       applyArm64Branch26(Off, S - P); break;
  case IMAGE_REL_ARM64_BRANCH19:       applyArm64Branch19(Off, S - P); break;
  case IMAGE_REL_ARM64_BRANCH14:       applyArm64Branch14(Off, S - P); break;
  case IMAGE_REL_ARM64_ADDR32:         add32(Off, S + Config->ImageBase); break;
  case IMAGE_REL_ARM64_ADDR32NB:       add32(Off, S); break;
  case IMAGE_REL_ARM64_ADDR64:         add64(Off, S + Config->ImageBase); break;
  case IMAGE_REL_ARM64_SECREL:         applySecRel(this, Off, OS, S); break;
  case IMAGE_REL_ARM64_SECREL_LOW12A:  applySecRelLow12A(this, Off, OS, S); break;
  case IMAGE_REL_ARM64_SECREL_HIGH12A: applySecRelHigh12A(this, Off, OS, S); break;
  case IMAGE_REL_ARM64_SECREL_LOW12L:  applySecRelLdr(this, Off, OS, S); break;
  case IMAGE_REL_ARM64_SECTION:        applySecIdx(Off, OS); break;
  default:
    fatal("unsupported relocation type 0x" + Twine::utohexstr(Type) + " in " +
          toString(File));
  }
}

void SectionChunk::writeTo(uint8_t *Buf) const {
  if (!hasData())
    return;
  // Copy section contents from source object file to output file.
  ArrayRef<uint8_t> A = getContents();
  if (!A.empty())
    memcpy(Buf + OutputSectionOff, A.data(), A.size());

  // Apply relocations.
  size_t InputSize = getSize();
  for (const coff_relocation &Rel : Relocs) {
    // Check for an invalid relocation offset. This check isn't perfect, because
    // we don't have the relocation size, which is only known after checking the
    // machine and relocation type. As a result, a relocation may overwrite the
    // beginning of the following input section.
    if (Rel.VirtualAddress >= InputSize)
      fatal("relocation points beyond the end of its parent section");

    uint8_t *Off = Buf + OutputSectionOff + Rel.VirtualAddress;

    // Get the output section of the symbol for this relocation.  The output
    // section is needed to compute SECREL and SECTION relocations used in debug
    // info.
    auto *Sym =
        dyn_cast_or_null<Defined>(File->getSymbol(Rel.SymbolTableIndex));
    if (!Sym) {
      if (isCodeView() || isDWARF())
        continue;
      // Symbols in early discarded sections are represented using null pointers,
      // so we need to retrieve the name from the object file.
      COFFSymbolRef Sym =
          check(File->getCOFFObj()->getSymbol(Rel.SymbolTableIndex));
      StringRef Name;
      File->getCOFFObj()->getSymbolName(Sym, Name);
      fatal("relocation against symbol in discarded section: " + Name);
    }
    Chunk *C = Sym->getChunk();
    OutputSection *OS = C ? C->getOutputSection() : nullptr;

    // Only absolute and __ImageBase symbols lack an output section. For any
    // other symbol, this indicates that the chunk was discarded.  Normally
    // relocations against discarded sections are an error.  However, debug info
    // sections are not GC roots and can end up with these kinds of relocations.
    // Skip these relocations.
    if (!OS && !isa<DefinedAbsolute>(Sym) && !isa<DefinedSynthetic>(Sym)) {
      if (isCodeView() || isDWARF())
        continue;
      fatal("relocation against symbol in discarded section: " +
            Sym->getName());
    }
    uint64_t S = Sym->getRVA();

    // Compute the RVA of the relocation for relative relocations.
    uint64_t P = RVA + Rel.VirtualAddress;
    switch (Config->Machine) {
    case AMD64:
      applyRelX64(Off, Rel.Type, OS, S, P);
      break;
    case I386:
      applyRelX86(Off, Rel.Type, OS, S, P);
      break;
    case ARMNT:
      applyRelARM(Off, Rel.Type, OS, S, P);
      break;
    case ARM64:
      applyRelARM64(Off, Rel.Type, OS, S, P);
      break;
    default:
      llvm_unreachable("unknown machine type");
    }
  }
}

void SectionChunk::addAssociative(SectionChunk *Child) {
  AssocChildren.push_back(Child);
}

static uint8_t getBaserelType(const coff_relocation &Rel) {
  switch (Config->Machine) {
  case AMD64:
    if (Rel.Type == IMAGE_REL_AMD64_ADDR64)
      return IMAGE_REL_BASED_DIR64;
    return IMAGE_REL_BASED_ABSOLUTE;
  case I386:
    if (Rel.Type == IMAGE_REL_I386_DIR32)
      return IMAGE_REL_BASED_HIGHLOW;
    return IMAGE_REL_BASED_ABSOLUTE;
  case ARMNT:
    if (Rel.Type == IMAGE_REL_ARM_ADDR32)
      return IMAGE_REL_BASED_HIGHLOW;
    if (Rel.Type == IMAGE_REL_ARM_MOV32T)
      return IMAGE_REL_BASED_ARM_MOV32T;
    return IMAGE_REL_BASED_ABSOLUTE;
  case ARM64:
    if (Rel.Type == IMAGE_REL_ARM64_ADDR64)
      return IMAGE_REL_BASED_DIR64;
    return IMAGE_REL_BASED_ABSOLUTE;
  default:
    llvm_unreachable("unknown machine type");
  }
}

// Windows-specific.
// Collect all locations that contain absolute addresses, which need to be
// fixed by the loader if load-time relocation is needed.
// Only called when base relocation is enabled.
void SectionChunk::getBaserels(std::vector<Baserel> *Res) {
  for (const coff_relocation &Rel : Relocs) {
    uint8_t Ty = getBaserelType(Rel);
    if (Ty == IMAGE_REL_BASED_ABSOLUTE)
      continue;
    Symbol *Target = File->getSymbol(Rel.SymbolTableIndex);
    if (!Target || isa<DefinedAbsolute>(Target))
      continue;
    Res->emplace_back(RVA + Rel.VirtualAddress, Ty);
  }
}

bool SectionChunk::hasData() const {
  return !(Header->Characteristics & IMAGE_SCN_CNT_UNINITIALIZED_DATA);
}

uint32_t SectionChunk::getOutputCharacteristics() const {
  return Header->Characteristics & (PermMask | TypeMask);
}

bool SectionChunk::isCOMDAT() const {
  return Header->Characteristics & IMAGE_SCN_LNK_COMDAT;
}

void SectionChunk::printDiscardedMessage() const {
  // Removed by dead-stripping. If it's removed by ICF, ICF already
  // printed out the name, so don't repeat that here.
  if (Sym && this == Repl)
    message("Discarded " + Sym->getName());
}

StringRef SectionChunk::getDebugName() {
  if (Sym)
    return Sym->getName();
  return "";
}

ArrayRef<uint8_t> SectionChunk::getContents() const {
  ArrayRef<uint8_t> A;
  File->getCOFFObj()->getSectionContents(Header, A);
  return A;
}

void SectionChunk::replace(SectionChunk *Other) {
  Alignment = std::max(Alignment, Other->Alignment);
  Other->Repl = Repl;
  Other->Live = false;
}

CommonChunk::CommonChunk(const COFFSymbolRef S) : Sym(S) {
  // Common symbols are aligned on natural boundaries up to 32 bytes.
  // This is what MSVC link.exe does.
  Alignment = std::min(uint64_t(32), PowerOf2Ceil(Sym.getValue()));
}

uint32_t CommonChunk::getOutputCharacteristics() const {
  return IMAGE_SCN_CNT_UNINITIALIZED_DATA | IMAGE_SCN_MEM_READ |
         IMAGE_SCN_MEM_WRITE;
}

void StringChunk::writeTo(uint8_t *Buf) const {
  memcpy(Buf + OutputSectionOff, Str.data(), Str.size());
}

ImportThunkChunkX64::ImportThunkChunkX64(Defined *S) : ImpSymbol(S) {
  // Intel Optimization Manual says that all branch targets
  // should be 16-byte aligned. MSVC linker does this too.
  Alignment = 16;
}

void ImportThunkChunkX64::writeTo(uint8_t *Buf) const {
  memcpy(Buf + OutputSectionOff, ImportThunkX86, sizeof(ImportThunkX86));
  // The first two bytes is a JMP instruction. Fill its operand.
  write32le(Buf + OutputSectionOff + 2, ImpSymbol->getRVA() - RVA - getSize());
}

void ImportThunkChunkX86::getBaserels(std::vector<Baserel> *Res) {
  Res->emplace_back(getRVA() + 2);
}

void ImportThunkChunkX86::writeTo(uint8_t *Buf) const {
  memcpy(Buf + OutputSectionOff, ImportThunkX86, sizeof(ImportThunkX86));
  // The first two bytes is a JMP instruction. Fill its operand.
  write32le(Buf + OutputSectionOff + 2,
            ImpSymbol->getRVA() + Config->ImageBase);
}

void ImportThunkChunkARM::getBaserels(std::vector<Baserel> *Res) {
  Res->emplace_back(getRVA(), IMAGE_REL_BASED_ARM_MOV32T);
}

void ImportThunkChunkARM::writeTo(uint8_t *Buf) const {
  memcpy(Buf + OutputSectionOff, ImportThunkARM, sizeof(ImportThunkARM));
  // Fix mov.w and mov.t operands.
  applyMOV32T(Buf + OutputSectionOff, ImpSymbol->getRVA() + Config->ImageBase);
}

void ImportThunkChunkARM64::writeTo(uint8_t *Buf) const {
  int64_t Off = ImpSymbol->getRVA() & 0xfff;
  memcpy(Buf + OutputSectionOff, ImportThunkARM64, sizeof(ImportThunkARM64));
  applyArm64Addr(Buf + OutputSectionOff, ImpSymbol->getRVA(), RVA, 12);
  applyArm64Ldr(Buf + OutputSectionOff + 4, Off);
}

void LocalImportChunk::getBaserels(std::vector<Baserel> *Res) {
  Res->emplace_back(getRVA());
}

size_t LocalImportChunk::getSize() const {
  return Config->is64() ? 8 : 4;
}

void LocalImportChunk::writeTo(uint8_t *Buf) const {
  if (Config->is64()) {
    write64le(Buf + OutputSectionOff, Sym->getRVA() + Config->ImageBase);
  } else {
    write32le(Buf + OutputSectionOff, Sym->getRVA() + Config->ImageBase);
  }
}

void RVATableChunk::writeTo(uint8_t *Buf) const {
  ulittle32_t *Begin = reinterpret_cast<ulittle32_t *>(Buf + OutputSectionOff);
  size_t Cnt = 0;
  for (const ChunkAndOffset &CO : Syms)
    Begin[Cnt++] = CO.InputChunk->getRVA() + CO.Offset;
  std::sort(Begin, Begin + Cnt);
  assert(std::unique(Begin, Begin + Cnt) == Begin + Cnt &&
         "RVA tables should be de-duplicated");
}

// Windows-specific. This class represents a block in .reloc section.
// The format is described here.
//
// On Windows, each DLL is linked against a fixed base address and
// usually loaded to that address. However, if there's already another
// DLL that overlaps, the loader has to relocate it. To do that, DLLs
// contain .reloc sections which contain offsets that need to be fixed
// up at runtime. If the loader finds that a DLL cannot be loaded to its
// desired base address, it loads it to somewhere else, and add <actual
// base address> - <desired base address> to each offset that is
// specified by the .reloc section. In ELF terms, .reloc sections
// contain relative relocations in REL format (as opposed to RELA.)
//
// This already significantly reduces the size of relocations compared
// to ELF .rel.dyn, but Windows does more to reduce it (probably because
// it was invented for PCs in the late '80s or early '90s.)  Offsets in
// .reloc are grouped by page where the page size is 12 bits, and
// offsets sharing the same page address are stored consecutively to
// represent them with less space. This is very similar to the page
// table which is grouped by (multiple stages of) pages.
//
// For example, let's say we have 0x00030, 0x00500, 0x00700, 0x00A00,
// 0x20004, and 0x20008 in a .reloc section for x64. The uppermost 4
// bits have a type IMAGE_REL_BASED_DIR64 or 0xA. In the section, they
// are represented like this:
//
//   0x00000  -- page address (4 bytes)
//   16       -- size of this block (4 bytes)
//     0xA030 -- entries (2 bytes each)
//     0xA500
//     0xA700
//     0xAA00
//   0x20000  -- page address (4 bytes)
//   12       -- size of this block (4 bytes)
//     0xA004 -- entries (2 bytes each)
//     0xA008
//
// Usually we have a lot of relocations for each page, so the number of
// bytes for one .reloc entry is close to 2 bytes on average.
BaserelChunk::BaserelChunk(uint32_t Page, Baserel *Begin, Baserel *End) {
  // Block header consists of 4 byte page RVA and 4 byte block size.
  // Each entry is 2 byte. Last entry may be padding.
  Data.resize(alignTo((End - Begin) * 2 + 8, 4));
  uint8_t *P = Data.data();
  write32le(P, Page);
  write32le(P + 4, Data.size());
  P += 8;
  for (Baserel *I = Begin; I != End; ++I) {
    write16le(P, (I->Type << 12) | (I->RVA - Page));
    P += 2;
  }
}

void BaserelChunk::writeTo(uint8_t *Buf) const {
  memcpy(Buf + OutputSectionOff, Data.data(), Data.size());
}

uint8_t Baserel::getDefaultType() {
  switch (Config->Machine) {
  case AMD64:
  case ARM64:
    return IMAGE_REL_BASED_DIR64;
  case I386:
  case ARMNT:
    return IMAGE_REL_BASED_HIGHLOW;
  default:
    llvm_unreachable("unknown machine type");
  }
}

std::map<uint32_t, MergeChunk *> MergeChunk::Instances;

MergeChunk::MergeChunk(uint32_t Alignment)
    : Builder(StringTableBuilder::RAW, Alignment) {
  this->Alignment = Alignment;
}

void MergeChunk::addSection(SectionChunk *C) {
  auto *&MC = Instances[C->Alignment];
  if (!MC)
    MC = make<MergeChunk>(C->Alignment);
  MC->Sections.push_back(C);
}

void MergeChunk::finalizeContents() {
  for (SectionChunk *C : Sections)
    if (C->isLive())
      Builder.add(toStringRef(C->getContents()));
  Builder.finalize();

  for (SectionChunk *C : Sections) {
    if (!C->isLive())
      continue;
    size_t Off = Builder.getOffset(toStringRef(C->getContents()));
    C->setOutputSection(Out);
    C->setRVA(RVA + Off);
    C->OutputSectionOff = OutputSectionOff + Off;
  }
}

uint32_t MergeChunk::getOutputCharacteristics() const {
  return IMAGE_SCN_MEM_READ | IMAGE_SCN_CNT_INITIALIZED_DATA;
}

size_t MergeChunk::getSize() const {
  return Builder.getSize();
}

void MergeChunk::writeTo(uint8_t *Buf) const {
  Builder.write(Buf + OutputSectionOff);
}

} // namespace coff
} // namespace lld
