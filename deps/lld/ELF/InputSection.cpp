//===- InputSection.cpp ---------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "InputSection.h"
#include "Config.h"
#include "EhFrame.h"
#include "InputFiles.h"
#include "LinkerScript.h"
#include "OutputSections.h"
#include "Relocations.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "Thunks.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "llvm/Object/Decompressor.h"
#include "llvm/Support/Compiler.h"
#include "llvm/Support/Compression.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/Threading.h"
#include "llvm/Support/xxhash.h"
#include <mutex>

using namespace llvm;
using namespace llvm::ELF;
using namespace llvm::object;
using namespace llvm::support;
using namespace llvm::support::endian;
using namespace llvm::sys;

using namespace lld;
using namespace lld::elf;

std::vector<InputSectionBase *> elf::InputSections;

// Returns a string to construct an error message.
std::string lld::toString(const InputSectionBase *Sec) {
  return (toString(Sec->File) + ":(" + Sec->Name + ")").str();
}

DenseMap<SectionBase *, int> elf::buildSectionOrder() {
  DenseMap<SectionBase *, int> SectionOrder;
  if (Config->SymbolOrderingFile.empty())
    return SectionOrder;

  // Build a map from symbols to their priorities. Symbols that didn't
  // appear in the symbol ordering file have the lowest priority 0.
  // All explicitly mentioned symbols have negative (higher) priorities.
  DenseMap<StringRef, int> SymbolOrder;
  int Priority = -Config->SymbolOrderingFile.size();
  for (StringRef S : Config->SymbolOrderingFile)
    SymbolOrder.insert({S, Priority++});

  // Build a map from sections to their priorities.
  for (InputFile *File : ObjectFiles) {
    for (Symbol *Sym : File->getSymbols()) {
      auto *D = dyn_cast<Defined>(Sym);
      if (!D || !D->Section)
        continue;
      int &Priority = SectionOrder[D->Section];
      Priority = std::min(Priority, SymbolOrder.lookup(D->getName()));
    }
  }
  return SectionOrder;
}

template <class ELFT>
static ArrayRef<uint8_t> getSectionContents(ObjFile<ELFT> &File,
                                            const typename ELFT::Shdr &Hdr) {
  if (Hdr.sh_type == SHT_NOBITS)
    return makeArrayRef<uint8_t>(nullptr, Hdr.sh_size);
  return check(File.getObj().getSectionContents(&Hdr));
}

InputSectionBase::InputSectionBase(InputFile *File, uint64_t Flags,
                                   uint32_t Type, uint64_t Entsize,
                                   uint32_t Link, uint32_t Info,
                                   uint32_t Alignment, ArrayRef<uint8_t> Data,
                                   StringRef Name, Kind SectionKind)
    : SectionBase(SectionKind, Name, Flags, Entsize, Alignment, Type, Info,
                  Link),
      File(File), Data(Data) {
  // In order to reduce memory allocation, we assume that mergeable
  // sections are smaller than 4 GiB, which is not an unreasonable
  // assumption as of 2017.
  if (SectionKind == SectionBase::Merge && Data.size() > UINT32_MAX)
    error(toString(this) + ": section too large");

  NumRelocations = 0;
  AreRelocsRela = false;

  // The ELF spec states that a value of 0 means the section has
  // no alignment constraits.
  uint32_t V = std::max<uint64_t>(Alignment, 1);
  if (!isPowerOf2_64(V))
    fatal(toString(File) + ": section sh_addralign is not a power of 2");
  this->Alignment = V;
}

// Drop SHF_GROUP bit unless we are producing a re-linkable object file.
// SHF_GROUP is a marker that a section belongs to some comdat group.
// That flag doesn't make sense in an executable.
static uint64_t getFlags(uint64_t Flags) {
  Flags &= ~(uint64_t)SHF_INFO_LINK;
  if (!Config->Relocatable)
    Flags &= ~(uint64_t)SHF_GROUP;
  return Flags;
}

// GNU assembler 2.24 and LLVM 4.0.0's MC (the newest release as of
// March 2017) fail to infer section types for sections starting with
// ".init_array." or ".fini_array.". They set SHT_PROGBITS instead of
// SHF_INIT_ARRAY. As a result, the following assembler directive
// creates ".init_array.100" with SHT_PROGBITS, for example.
//
//   .section .init_array.100, "aw"
//
// This function forces SHT_{INIT,FINI}_ARRAY so that we can handle
// incorrect inputs as if they were correct from the beginning.
static uint64_t getType(uint64_t Type, StringRef Name) {
  if (Type == SHT_PROGBITS && Name.startswith(".init_array."))
    return SHT_INIT_ARRAY;
  if (Type == SHT_PROGBITS && Name.startswith(".fini_array."))
    return SHT_FINI_ARRAY;
  return Type;
}

template <class ELFT>
InputSectionBase::InputSectionBase(ObjFile<ELFT> &File,
                                   const typename ELFT::Shdr &Hdr,
                                   StringRef Name, Kind SectionKind)
    : InputSectionBase(&File, getFlags(Hdr.sh_flags),
                       getType(Hdr.sh_type, Name), Hdr.sh_entsize, Hdr.sh_link,
                       Hdr.sh_info, Hdr.sh_addralign,
                       getSectionContents(File, Hdr), Name, SectionKind) {
  // We reject object files having insanely large alignments even though
  // they are allowed by the spec. I think 4GB is a reasonable limitation.
  // We might want to relax this in the future.
  if (Hdr.sh_addralign > UINT32_MAX)
    fatal(toString(&File) + ": section sh_addralign is too large");
}

size_t InputSectionBase::getSize() const {
  if (auto *S = dyn_cast<SyntheticSection>(this))
    return S->getSize();

  return Data.size();
}

uint64_t InputSectionBase::getOffsetInFile() const {
  const uint8_t *FileStart = (const uint8_t *)File->MB.getBufferStart();
  const uint8_t *SecStart = Data.begin();
  return SecStart - FileStart;
}

uint64_t SectionBase::getOffset(uint64_t Offset) const {
  switch (kind()) {
  case Output: {
    auto *OS = cast<OutputSection>(this);
    // For output sections we treat offset -1 as the end of the section.
    return Offset == uint64_t(-1) ? OS->Size : Offset;
  }
  case Regular:
    return cast<InputSection>(this)->OutSecOff + Offset;
  case Synthetic: {
    auto *IS = cast<InputSection>(this);
    // For synthetic sections we treat offset -1 as the end of the section.
    return IS->OutSecOff + (Offset == uint64_t(-1) ? IS->getSize() : Offset);
  }
  case EHFrame:
    // The file crtbeginT.o has relocations pointing to the start of an empty
    // .eh_frame that is known to be the first in the link. It does that to
    // identify the start of the output .eh_frame.
    return Offset;
  case Merge:
    const MergeInputSection *MS = cast<MergeInputSection>(this);
    if (InputSection *IS = MS->getParent())
      return IS->OutSecOff + MS->getOffset(Offset);
    return MS->getOffset(Offset);
  }
  llvm_unreachable("invalid section kind");
}

OutputSection *SectionBase::getOutputSection() {
  InputSection *Sec;
  if (auto *IS = dyn_cast<InputSection>(this))
    return IS->getParent();
  else if (auto *MS = dyn_cast<MergeInputSection>(this))
    Sec = MS->getParent();
  else if (auto *EH = dyn_cast<EhInputSection>(this))
    Sec = EH->getParent();
  else
    return cast<OutputSection>(this);
  return Sec ? Sec->getParent() : nullptr;
}

// Uncompress section contents if required. Note that this function
// is called from parallelForEach, so it must be thread-safe.
void InputSectionBase::maybeUncompress() {
  if (UncompressBuf || !Decompressor::isCompressedELFSection(Flags, Name))
    return;

  Decompressor Dec = check(Decompressor::create(Name, toStringRef(Data),
                                                Config->IsLE, Config->Is64));

  size_t Size = Dec.getDecompressedSize();
  UncompressBuf.reset(new char[Size]());
  if (Error E = Dec.decompress({UncompressBuf.get(), Size}))
    fatal(toString(this) +
          ": decompress failed: " + llvm::toString(std::move(E)));

  Data = makeArrayRef((uint8_t *)UncompressBuf.get(), Size);
  Flags &= ~(uint64_t)SHF_COMPRESSED;
}

InputSection *InputSectionBase::getLinkOrderDep() const {
  if ((Flags & SHF_LINK_ORDER) && Link != 0) {
    InputSectionBase *L = File->getSections()[Link];
    if (auto *IS = dyn_cast<InputSection>(L))
      return IS;
    error("a section with SHF_LINK_ORDER should not refer a non-regular "
          "section: " +
          toString(L));
  }
  return nullptr;
}

// Returns a source location string. Used to construct an error message.
template <class ELFT>
std::string InputSectionBase::getLocation(uint64_t Offset) {
  // We don't have file for synthetic sections.
  if (getFile<ELFT>() == nullptr)
    return (Config->OutputFile + ":(" + Name + "+0x" + utohexstr(Offset) + ")")
        .str();

  // First check if we can get desired values from debugging information.
  std::string LineInfo = getFile<ELFT>()->getLineInfo(this, Offset);
  if (!LineInfo.empty())
    return LineInfo;

  // File->SourceFile contains STT_FILE symbol that contains a
  // source file name. If it's missing, we use an object file name.
  std::string SrcFile = getFile<ELFT>()->SourceFile;
  if (SrcFile.empty())
    SrcFile = toString(File);

  // Find a function symbol that encloses a given location.
  for (Symbol *B : File->getSymbols())
    if (auto *D = dyn_cast<Defined>(B))
      if (D->Section == this && D->Type == STT_FUNC)
        if (D->Value <= Offset && Offset < D->Value + D->Size)
          return SrcFile + ":(function " + toString(*D) + ")";

  // If there's no symbol, print out the offset in the section.
  return (SrcFile + ":(" + Name + "+0x" + utohexstr(Offset) + ")").str();
}

// This function is intended to be used for constructing an error message.
// The returned message looks like this:
//
//   foo.c:42 (/home/alice/possibly/very/long/path/foo.c:42)
//
//  Returns an empty string if there's no way to get line info.
std::string InputSectionBase::getSrcMsg(const Symbol &Sym, uint64_t Offset) {
  // Synthetic sections don't have input files.
  if (!File)
    return "";
  return File->getSrcMsg(Sym, *this, Offset);
}

// Returns a filename string along with an optional section name. This
// function is intended to be used for constructing an error
// message. The returned message looks like this:
//
//   path/to/foo.o:(function bar)
//
// or
//
//   path/to/foo.o:(function bar) in archive path/to/bar.a
std::string InputSectionBase::getObjMsg(uint64_t Off) {
  // Synthetic sections don't have input files.
  if (!File)
    return ("<internal>:(" + Name + "+0x" + utohexstr(Off) + ")").str();
  std::string Filename = File->getName();

  std::string Archive;
  if (!File->ArchiveName.empty())
    Archive = (" in archive " + File->ArchiveName).str();

  // Find a symbol that encloses a given location.
  for (Symbol *B : File->getSymbols())
    if (auto *D = dyn_cast<Defined>(B))
      if (D->Section == this && D->Value <= Off && Off < D->Value + D->Size)
        return Filename + ":(" + toString(*D) + ")" + Archive;

  // If there's no symbol, print out the offset in the section.
  return (Filename + ":(" + Name + "+0x" + utohexstr(Off) + ")" + Archive)
      .str();
}

InputSection InputSection::Discarded(nullptr, 0, 0, 0, ArrayRef<uint8_t>(), "");

InputSection::InputSection(InputFile *F, uint64_t Flags, uint32_t Type,
                           uint32_t Alignment, ArrayRef<uint8_t> Data,
                           StringRef Name, Kind K)
    : InputSectionBase(F, Flags, Type,
                       /*Entsize*/ 0, /*Link*/ 0, /*Info*/ 0, Alignment, Data,
                       Name, K) {}

template <class ELFT>
InputSection::InputSection(ObjFile<ELFT> &F, const typename ELFT::Shdr &Header,
                           StringRef Name)
    : InputSectionBase(F, Header, Name, InputSectionBase::Regular) {}

bool InputSection::classof(const SectionBase *S) {
  return S->kind() == SectionBase::Regular ||
         S->kind() == SectionBase::Synthetic;
}

OutputSection *InputSection::getParent() const {
  return cast_or_null<OutputSection>(Parent);
}

// Copy SHT_GROUP section contents. Used only for the -r option.
template <class ELFT> void InputSection::copyShtGroup(uint8_t *Buf) {
  // ELFT::Word is the 32-bit integral type in the target endianness.
  typedef typename ELFT::Word u32;
  ArrayRef<u32> From = getDataAs<u32>();
  auto *To = reinterpret_cast<u32 *>(Buf);

  // The first entry is not a section number but a flag.
  *To++ = From[0];

  // Adjust section numbers because section numbers in an input object
  // files are different in the output.
  ArrayRef<InputSectionBase *> Sections = File->getSections();
  for (uint32_t Idx : From.slice(1))
    *To++ = Sections[Idx]->getOutputSection()->SectionIndex;
}

InputSectionBase *InputSection::getRelocatedSection() {
  assert(Type == SHT_RELA || Type == SHT_REL);
  ArrayRef<InputSectionBase *> Sections = File->getSections();
  return Sections[Info];
}

// This is used for -r and --emit-relocs. We can't use memcpy to copy
// relocations because we need to update symbol table offset and section index
// for each relocation. So we copy relocations one by one.
template <class ELFT, class RelTy>
void InputSection::copyRelocations(uint8_t *Buf, ArrayRef<RelTy> Rels) {
  InputSectionBase *Sec = getRelocatedSection();

  for (const RelTy &Rel : Rels) {
    RelType Type = Rel.getType(Config->IsMips64EL);
    Symbol &Sym = getFile<ELFT>()->getRelocTargetSym(Rel);

    auto *P = reinterpret_cast<typename ELFT::Rela *>(Buf);
    Buf += sizeof(RelTy);

    if (Config->IsRela)
      P->r_addend = getAddend<ELFT>(Rel);

    // Output section VA is zero for -r, so r_offset is an offset within the
    // section, but for --emit-relocs it is an virtual address.
    P->r_offset = Sec->getOutputSection()->Addr + Sec->getOffset(Rel.r_offset);
    P->setSymbolAndType(InX::SymTab->getSymbolIndex(&Sym), Type,
                        Config->IsMips64EL);

    if (Sym.Type == STT_SECTION) {
      // We combine multiple section symbols into only one per
      // section. This means we have to update the addend. That is
      // trivial for Elf_Rela, but for Elf_Rel we have to write to the
      // section data. We do that by adding to the Relocation vector.

      // .eh_frame is horribly special and can reference discarded sections. To
      // avoid having to parse and recreate .eh_frame, we just replace any
      // relocation in it pointing to discarded sections with R_*_NONE, which
      // hopefully creates a frame that is ignored at runtime.
      auto *D = dyn_cast<Defined>(&Sym);
      if (!D) {
        error("STT_SECTION symbol should be defined");
        continue;
      }
      SectionBase *Section = D->Section;
      if (Section == &InputSection::Discarded) {
        P->setSymbolAndType(0, 0, false);
        continue;
      }

      if (Config->IsRela) {
        P->r_addend =
            Sym.getVA(getAddend<ELFT>(Rel)) - Section->getOutputSection()->Addr;
      } else if (Config->Relocatable) {
        const uint8_t *BufLoc = Sec->Data.begin() + Rel.r_offset;
        Sec->Relocations.push_back({R_ABS, Type, Rel.r_offset,
                                    Target->getImplicitAddend(BufLoc, Type),
                                    &Sym});
      }
    }

  }
}

// The ARM and AArch64 ABI handle pc-relative relocations to undefined weak
// references specially. The general rule is that the value of the symbol in
// this context is the address of the place P. A further special case is that
// branch relocations to an undefined weak reference resolve to the next
// instruction.
static uint32_t getARMUndefinedRelativeWeakVA(RelType Type, uint32_t A,
                                              uint32_t P) {
  switch (Type) {
  // Unresolved branch relocations to weak references resolve to next
  // instruction, this will be either 2 or 4 bytes on from P.
  case R_ARM_THM_JUMP11:
    return P + 2 + A;
  case R_ARM_CALL:
  case R_ARM_JUMP24:
  case R_ARM_PC24:
  case R_ARM_PLT32:
  case R_ARM_PREL31:
  case R_ARM_THM_JUMP19:
  case R_ARM_THM_JUMP24:
    return P + 4 + A;
  case R_ARM_THM_CALL:
    // We don't want an interworking BLX to ARM
    return P + 5 + A;
  // Unresolved non branch pc-relative relocations
  // R_ARM_TARGET2 which can be resolved relatively is not present as it never
  // targets a weak-reference.
  case R_ARM_MOVW_PREL_NC:
  case R_ARM_MOVT_PREL:
  case R_ARM_REL32:
  case R_ARM_THM_MOVW_PREL_NC:
  case R_ARM_THM_MOVT_PREL:
    return P + A;
  }
  llvm_unreachable("ARM pc-relative relocation expected\n");
}

// The comment above getARMUndefinedRelativeWeakVA applies to this function.
static uint64_t getAArch64UndefinedRelativeWeakVA(uint64_t Type, uint64_t A,
                                                  uint64_t P) {
  switch (Type) {
  // Unresolved branch relocations to weak references resolve to next
  // instruction, this is 4 bytes on from P.
  case R_AARCH64_CALL26:
  case R_AARCH64_CONDBR19:
  case R_AARCH64_JUMP26:
  case R_AARCH64_TSTBR14:
    return P + 4 + A;
  // Unresolved non branch pc-relative relocations
  case R_AARCH64_PREL16:
  case R_AARCH64_PREL32:
  case R_AARCH64_PREL64:
  case R_AARCH64_ADR_PREL_LO21:
  case R_AARCH64_LD_PREL_LO19:
    return P + A;
  }
  llvm_unreachable("AArch64 pc-relative relocation expected\n");
}

// ARM SBREL relocations are of the form S + A - B where B is the static base
// The ARM ABI defines base to be "addressing origin of the output segment
// defining the symbol S". We defined the "addressing origin"/static base to be
// the base of the PT_LOAD segment containing the Sym.
// The procedure call standard only defines a Read Write Position Independent
// RWPI variant so in practice we should expect the static base to be the base
// of the RW segment.
static uint64_t getARMStaticBase(const Symbol &Sym) {
  OutputSection *OS = Sym.getOutputSection();
  if (!OS || !OS->PtLoad || !OS->PtLoad->FirstSec)
    fatal("SBREL relocation to " + Sym.getName() + " without static base");
  return OS->PtLoad->FirstSec->Addr;
}

static uint64_t getRelocTargetVA(RelType Type, int64_t A, uint64_t P,
                                 const Symbol &Sym, RelExpr Expr) {
  switch (Expr) {
  case R_INVALID:
    return 0;
  case R_ABS:
  case R_RELAX_GOT_PC_NOPIC:
    return Sym.getVA(A);
  case R_ARM_SBREL:
    return Sym.getVA(A) - getARMStaticBase(Sym);
  case R_GOT:
  case R_RELAX_TLS_GD_TO_IE_ABS:
    return Sym.getGotVA() + A;
  case R_GOTONLY_PC:
    return InX::Got->getVA() + A - P;
  case R_GOTONLY_PC_FROM_END:
    return InX::Got->getVA() + A - P + InX::Got->getSize();
  case R_GOTREL:
    return Sym.getVA(A) - InX::Got->getVA();
  case R_GOTREL_FROM_END:
    return Sym.getVA(A) - InX::Got->getVA() - InX::Got->getSize();
  case R_GOT_FROM_END:
  case R_RELAX_TLS_GD_TO_IE_END:
    return Sym.getGotOffset() + A - InX::Got->getSize();
  case R_GOT_OFF:
    return Sym.getGotOffset() + A;
  case R_GOT_PAGE_PC:
  case R_RELAX_TLS_GD_TO_IE_PAGE_PC:
    return getAArch64Page(Sym.getGotVA() + A) - getAArch64Page(P);
  case R_GOT_PC:
  case R_RELAX_TLS_GD_TO_IE:
    return Sym.getGotVA() + A - P;
  case R_HINT:
  case R_NONE:
  case R_TLSDESC_CALL:
    llvm_unreachable("cannot relocate hint relocs");
  case R_MIPS_GOTREL:
    return Sym.getVA(A) - InX::MipsGot->getGp();
  case R_MIPS_GOT_GP:
    return InX::MipsGot->getGp() + A;
  case R_MIPS_GOT_GP_PC: {
    // R_MIPS_LO16 expression has R_MIPS_GOT_GP_PC type iif the target
    // is _gp_disp symbol. In that case we should use the following
    // formula for calculation "AHL + GP - P + 4". For details see p. 4-19 at
    // ftp://www.linux-mips.org/pub/linux/mips/doc/ABI/mipsabi.pdf
    // microMIPS variants of these relocations use slightly different
    // expressions: AHL + GP - P + 3 for %lo() and AHL + GP - P - 1 for %hi()
    // to correctly handle less-sugnificant bit of the microMIPS symbol.
    uint64_t V = InX::MipsGot->getGp() + A - P;
    if (Type == R_MIPS_LO16 || Type == R_MICROMIPS_LO16)
      V += 4;
    if (Type == R_MICROMIPS_LO16 || Type == R_MICROMIPS_HI16)
      V -= 1;
    return V;
  }
  case R_MIPS_GOT_LOCAL_PAGE:
    // If relocation against MIPS local symbol requires GOT entry, this entry
    // should be initialized by 'page address'. This address is high 16-bits
    // of sum the symbol's value and the addend.
    return InX::MipsGot->getVA() + InX::MipsGot->getPageEntryOffset(Sym, A) -
           InX::MipsGot->getGp();
  case R_MIPS_GOT_OFF:
  case R_MIPS_GOT_OFF32:
    // In case of MIPS if a GOT relocation has non-zero addend this addend
    // should be applied to the GOT entry content not to the GOT entry offset.
    // That is why we use separate expression type.
    return InX::MipsGot->getVA() + InX::MipsGot->getSymEntryOffset(Sym, A) -
           InX::MipsGot->getGp();
  case R_MIPS_TLSGD:
    return InX::MipsGot->getVA() + InX::MipsGot->getTlsOffset() +
           InX::MipsGot->getGlobalDynOffset(Sym) - InX::MipsGot->getGp();
  case R_MIPS_TLSLD:
    return InX::MipsGot->getVA() + InX::MipsGot->getTlsOffset() +
           InX::MipsGot->getTlsIndexOff() - InX::MipsGot->getGp();
  case R_PAGE_PC:
  case R_PLT_PAGE_PC: {
    uint64_t Dest;
    if (Sym.isUndefWeak())
      Dest = getAArch64Page(A);
    else
      Dest = getAArch64Page(Sym.getVA(A));
    return Dest - getAArch64Page(P);
  }
  case R_PC: {
    uint64_t Dest;
    if (Sym.isUndefWeak()) {
      // On ARM and AArch64 a branch to an undefined weak resolves to the
      // next instruction, otherwise the place.
      if (Config->EMachine == EM_ARM)
        Dest = getARMUndefinedRelativeWeakVA(Type, A, P);
      else if (Config->EMachine == EM_AARCH64)
        Dest = getAArch64UndefinedRelativeWeakVA(Type, A, P);
      else
        Dest = Sym.getVA(A);
    } else {
      Dest = Sym.getVA(A);
    }
    return Dest - P;
  }
  case R_PLT:
    return Sym.getPltVA() + A;
  case R_PLT_PC:
  case R_PPC_PLT_OPD:
    return Sym.getPltVA() + A - P;
  case R_PPC_OPD: {
    uint64_t SymVA = Sym.getVA(A);
    // If we have an undefined weak symbol, we might get here with a symbol
    // address of zero. That could overflow, but the code must be unreachable,
    // so don't bother doing anything at all.
    if (!SymVA)
      return 0;
    if (Out::Opd) {
      // If this is a local call, and we currently have the address of a
      // function-descriptor, get the underlying code address instead.
      uint64_t OpdStart = Out::Opd->Addr;
      uint64_t OpdEnd = OpdStart + Out::Opd->Size;
      bool InOpd = OpdStart <= SymVA && SymVA < OpdEnd;
      if (InOpd)
        SymVA = read64be(&Out::OpdBuf[SymVA - OpdStart]);
    }
    return SymVA - P;
  }
  case R_PPC_TOC:
    return getPPC64TocBase() + A;
  case R_RELAX_GOT_PC:
    return Sym.getVA(A) - P;
  case R_RELAX_TLS_GD_TO_LE:
  case R_RELAX_TLS_IE_TO_LE:
  case R_RELAX_TLS_LD_TO_LE:
  case R_TLS:
    // A weak undefined TLS symbol resolves to the base of the TLS
    // block, i.e. gets a value of zero. If we pass --gc-sections to
    // lld and .tbss is not referenced, it gets reclaimed and we don't
    // create a TLS program header. Therefore, we resolve this
    // statically to zero.
    if (Sym.isTls() && Sym.isUndefWeak())
      return 0;
    if (Target->TcbSize)
      return Sym.getVA(A) + alignTo(Target->TcbSize, Out::TlsPhdr->p_align);
    return Sym.getVA(A) - Out::TlsPhdr->p_memsz;
  case R_RELAX_TLS_GD_TO_LE_NEG:
  case R_NEG_TLS:
    return Out::TlsPhdr->p_memsz - Sym.getVA(A);
  case R_SIZE:
    return A; // Sym.getSize was already folded into the addend.
  case R_TLSDESC:
    return InX::Got->getGlobalDynAddr(Sym) + A;
  case R_TLSDESC_PAGE:
    return getAArch64Page(InX::Got->getGlobalDynAddr(Sym) + A) -
           getAArch64Page(P);
  case R_TLSGD:
    return InX::Got->getGlobalDynOffset(Sym) + A - InX::Got->getSize();
  case R_TLSGD_PC:
    return InX::Got->getGlobalDynAddr(Sym) + A - P;
  case R_TLSLD:
    return InX::Got->getTlsIndexOff() + A - InX::Got->getSize();
  case R_TLSLD_PC:
    return InX::Got->getTlsIndexVA() + A - P;
  }
  llvm_unreachable("Invalid expression");
}

// This function applies relocations to sections without SHF_ALLOC bit.
// Such sections are never mapped to memory at runtime. Debug sections are
// an example. Relocations in non-alloc sections are much easier to
// handle than in allocated sections because it will never need complex
// treatement such as GOT or PLT (because at runtime no one refers them).
// So, we handle relocations for non-alloc sections directly in this
// function as a performance optimization.
template <class ELFT, class RelTy>
void InputSection::relocateNonAlloc(uint8_t *Buf, ArrayRef<RelTy> Rels) {
  const unsigned Bits = sizeof(typename ELFT::uint) * 8;

  for (const RelTy &Rel : Rels) {
    RelType Type = Rel.getType(Config->IsMips64EL);
    uint64_t Offset = getOffset(Rel.r_offset);
    uint8_t *BufLoc = Buf + Offset;
    int64_t Addend = getAddend<ELFT>(Rel);
    if (!RelTy::IsRela)
      Addend += Target->getImplicitAddend(BufLoc, Type);

    Symbol &Sym = getFile<ELFT>()->getRelocTargetSym(Rel);
    RelExpr Expr = Target->getRelExpr(Type, Sym, BufLoc);
    if (Expr == R_NONE)
      continue;
    if (Expr != R_ABS) {
      // GCC 8.0 or earlier have a bug that it emits R_386_GOTPC relocations
      // against _GLOBAL_OFFSET_TABLE for .debug_info. The bug seems to have
      // been fixed in 2017: https://gcc.gnu.org/bugzilla/show_bug.cgi?id=82630,
      // but we need to keep this bug-compatible code for a while.
      if (Config->EMachine == EM_386 && Type == R_386_GOTPC)
        continue;

      error(getLocation<ELFT>(Offset) + ": has non-ABS relocation " +
            toString(Type) + " against symbol '" + toString(Sym) + "'");
      return;
    }

    if (Sym.isTls() && !Out::TlsPhdr)
      Target->relocateOne(BufLoc, Type, 0);
    else
      Target->relocateOne(BufLoc, Type, SignExtend64<Bits>(Sym.getVA(Addend)));
  }
}

template <class ELFT>
void InputSectionBase::relocate(uint8_t *Buf, uint8_t *BufEnd) {
  if (Flags & SHF_ALLOC) {
    relocateAlloc(Buf, BufEnd);
    return;
  }

  auto *Sec = cast<InputSection>(this);
  if (Sec->AreRelocsRela)
    Sec->relocateNonAlloc<ELFT>(Buf, Sec->template relas<ELFT>());
  else
    Sec->relocateNonAlloc<ELFT>(Buf, Sec->template rels<ELFT>());
}

void InputSectionBase::relocateAlloc(uint8_t *Buf, uint8_t *BufEnd) {
  assert(Flags & SHF_ALLOC);
  const unsigned Bits = Config->Wordsize * 8;

  for (const Relocation &Rel : Relocations) {
    uint64_t Offset = getOffset(Rel.Offset);
    uint8_t *BufLoc = Buf + Offset;
    RelType Type = Rel.Type;

    uint64_t AddrLoc = getOutputSection()->Addr + Offset;
    RelExpr Expr = Rel.Expr;
    uint64_t TargetVA = SignExtend64(
        getRelocTargetVA(Type, Rel.Addend, AddrLoc, *Rel.Sym, Expr), Bits);

    switch (Expr) {
    case R_RELAX_GOT_PC:
    case R_RELAX_GOT_PC_NOPIC:
      Target->relaxGot(BufLoc, TargetVA);
      break;
    case R_RELAX_TLS_IE_TO_LE:
      Target->relaxTlsIeToLe(BufLoc, Type, TargetVA);
      break;
    case R_RELAX_TLS_LD_TO_LE:
      Target->relaxTlsLdToLe(BufLoc, Type, TargetVA);
      break;
    case R_RELAX_TLS_GD_TO_LE:
    case R_RELAX_TLS_GD_TO_LE_NEG:
      Target->relaxTlsGdToLe(BufLoc, Type, TargetVA);
      break;
    case R_RELAX_TLS_GD_TO_IE:
    case R_RELAX_TLS_GD_TO_IE_ABS:
    case R_RELAX_TLS_GD_TO_IE_PAGE_PC:
    case R_RELAX_TLS_GD_TO_IE_END:
      Target->relaxTlsGdToIe(BufLoc, Type, TargetVA);
      break;
    case R_PPC_PLT_OPD:
      // Patch a nop (0x60000000) to a ld.
      if (BufLoc + 8 <= BufEnd && read32be(BufLoc + 4) == 0x60000000)
        write32be(BufLoc + 4, 0xe8410028); // ld %r2, 40(%r1)
      LLVM_FALLTHROUGH;
    default:
      Target->relocateOne(BufLoc, Type, TargetVA);
      break;
    }
  }
}

template <class ELFT> void InputSection::writeTo(uint8_t *Buf) {
  if (Type == SHT_NOBITS)
    return;

  if (auto *S = dyn_cast<SyntheticSection>(this)) {
    S->writeTo(Buf + OutSecOff);
    return;
  }

  // If -r or --emit-relocs is given, then an InputSection
  // may be a relocation section.
  if (Type == SHT_RELA) {
    copyRelocations<ELFT>(Buf + OutSecOff, getDataAs<typename ELFT::Rela>());
    return;
  }
  if (Type == SHT_REL) {
    copyRelocations<ELFT>(Buf + OutSecOff, getDataAs<typename ELFT::Rel>());
    return;
  }

  // If -r is given, we may have a SHT_GROUP section.
  if (Type == SHT_GROUP) {
    copyShtGroup<ELFT>(Buf + OutSecOff);
    return;
  }

  // Copy section contents from source object file to output file
  // and then apply relocations.
  memcpy(Buf + OutSecOff, Data.data(), Data.size());
  uint8_t *BufEnd = Buf + OutSecOff + Data.size();
  relocate<ELFT>(Buf, BufEnd);
}

void InputSection::replace(InputSection *Other) {
  Alignment = std::max(Alignment, Other->Alignment);
  Other->Repl = Repl;
  Other->Live = false;
}

template <class ELFT>
EhInputSection::EhInputSection(ObjFile<ELFT> &F,
                               const typename ELFT::Shdr &Header,
                               StringRef Name)
    : InputSectionBase(F, Header, Name, InputSectionBase::EHFrame) {}

SyntheticSection *EhInputSection::getParent() const {
  return cast_or_null<SyntheticSection>(Parent);
}

// Returns the index of the first relocation that points to a region between
// Begin and Begin+Size.
template <class IntTy, class RelTy>
static unsigned getReloc(IntTy Begin, IntTy Size, const ArrayRef<RelTy> &Rels,
                         unsigned &RelocI) {
  // Start search from RelocI for fast access. That works because the
  // relocations are sorted in .eh_frame.
  for (unsigned N = Rels.size(); RelocI < N; ++RelocI) {
    const RelTy &Rel = Rels[RelocI];
    if (Rel.r_offset < Begin)
      continue;

    if (Rel.r_offset < Begin + Size)
      return RelocI;
    return -1;
  }
  return -1;
}

// .eh_frame is a sequence of CIE or FDE records.
// This function splits an input section into records and returns them.
template <class ELFT> void EhInputSection::split() {
  // Early exit if already split.
  if (!Pieces.empty())
    return;

  if (AreRelocsRela)
    split<ELFT>(relas<ELFT>());
  else
    split<ELFT>(rels<ELFT>());
}

template <class ELFT, class RelTy>
void EhInputSection::split(ArrayRef<RelTy> Rels) {
  unsigned RelI = 0;
  for (size_t Off = 0, End = Data.size(); Off != End;) {
    size_t Size = readEhRecordSize(this, Off);
    Pieces.emplace_back(Off, this, Size, getReloc(Off, Size, Rels, RelI));
    // The empty record is the end marker.
    if (Size == 4)
      break;
    Off += Size;
  }
}

static size_t findNull(StringRef S, size_t EntSize) {
  // Optimize the common case.
  if (EntSize == 1)
    return S.find(0);

  for (unsigned I = 0, N = S.size(); I != N; I += EntSize) {
    const char *B = S.begin() + I;
    if (std::all_of(B, B + EntSize, [](char C) { return C == 0; }))
      return I;
  }
  return StringRef::npos;
}

SyntheticSection *MergeInputSection::getParent() const {
  return cast_or_null<SyntheticSection>(Parent);
}

// Split SHF_STRINGS section. Such section is a sequence of
// null-terminated strings.
void MergeInputSection::splitStrings(ArrayRef<uint8_t> Data, size_t EntSize) {
  size_t Off = 0;
  bool IsAlloc = Flags & SHF_ALLOC;
  StringRef S = toStringRef(Data);

  while (!S.empty()) {
    size_t End = findNull(S, EntSize);
    if (End == StringRef::npos)
      fatal(toString(this) + ": string is not null terminated");
    size_t Size = End + EntSize;

    Pieces.emplace_back(Off, xxHash64(S.substr(0, Size)), !IsAlloc);
    S = S.substr(Size);
    Off += Size;
  }
}

// Split non-SHF_STRINGS section. Such section is a sequence of
// fixed size records.
void MergeInputSection::splitNonStrings(ArrayRef<uint8_t> Data,
                                        size_t EntSize) {
  size_t Size = Data.size();
  assert((Size % EntSize) == 0);
  bool IsAlloc = Flags & SHF_ALLOC;

  for (size_t I = 0; I != Size; I += EntSize)
    Pieces.emplace_back(I, xxHash64(toStringRef(Data.slice(I, EntSize))),
                        !IsAlloc);
}

template <class ELFT>
MergeInputSection::MergeInputSection(ObjFile<ELFT> &F,
                                     const typename ELFT::Shdr &Header,
                                     StringRef Name)
    : InputSectionBase(F, Header, Name, InputSectionBase::Merge) {}

MergeInputSection::MergeInputSection(uint64_t Flags, uint32_t Type,
                                     uint64_t Entsize, ArrayRef<uint8_t> Data,
                                     StringRef Name)
    : InputSectionBase(nullptr, Flags, Type, Entsize, /*Link*/ 0, /*Info*/ 0,
                       /*Alignment*/ Entsize, Data, Name, SectionBase::Merge) {}

// This function is called after we obtain a complete list of input sections
// that need to be linked. This is responsible to split section contents
// into small chunks for further processing.
//
// Note that this function is called from parallelForEach. This must be
// thread-safe (i.e. no memory allocation from the pools).
void MergeInputSection::splitIntoPieces() {
  assert(Pieces.empty());

  if (Flags & SHF_STRINGS)
    splitStrings(Data, Entsize);
  else
    splitNonStrings(Data, Entsize);

  if (Config->GcSections && (Flags & SHF_ALLOC))
    for (uint64_t Off : LiveOffsets)
      getSectionPiece(Off)->Live = true;
}

// Do binary search to get a section piece at a given input offset.
SectionPiece *MergeInputSection::getSectionPiece(uint64_t Offset) {
  auto *This = static_cast<const MergeInputSection *>(this);
  return const_cast<SectionPiece *>(This->getSectionPiece(Offset));
}

template <class It, class T, class Compare>
static It fastUpperBound(It First, It Last, const T &Value, Compare Comp) {
  size_t Size = std::distance(First, Last);
  assert(Size != 0);
  while (Size != 1) {
    size_t H = Size / 2;
    const It MI = First + H;
    Size -= H;
    First = Comp(Value, *MI) ? First : First + H;
  }
  return Comp(Value, *First) ? First : First + 1;
}

const SectionPiece *MergeInputSection::getSectionPiece(uint64_t Offset) const {
  if (Data.size() <= Offset)
    fatal(toString(this) + ": entry is past the end of the section");

  // Find the element this offset points to.
  auto I = fastUpperBound(
      Pieces.begin(), Pieces.end(), Offset,
      [](const uint64_t &A, const SectionPiece &B) { return A < B.InputOff; });
  --I;
  return &*I;
}

// Returns the offset in an output section for a given input offset.
// Because contents of a mergeable section is not contiguous in output,
// it is not just an addition to a base output offset.
uint64_t MergeInputSection::getOffset(uint64_t Offset) const {
  if (!Live)
    return 0;

  // Initialize OffsetMap lazily.
  llvm::call_once(InitOffsetMap, [&] {
    OffsetMap.reserve(Pieces.size());
    for (size_t I = 0; I < Pieces.size(); ++I)
      OffsetMap[Pieces[I].InputOff] = I;
  });

  // Find a string starting at a given offset.
  auto It = OffsetMap.find(Offset);
  if (It != OffsetMap.end())
    return Pieces[It->second].OutputOff;

  // If Offset is not at beginning of a section piece, it is not in the map.
  // In that case we need to search from the original section piece vector.
  const SectionPiece &Piece = *getSectionPiece(Offset);
  if (!Piece.Live)
    return 0;

  uint64_t Addend = Offset - Piece.InputOff;
  return Piece.OutputOff + Addend;
}

template InputSection::InputSection(ObjFile<ELF32LE> &, const ELF32LE::Shdr &,
                                    StringRef);
template InputSection::InputSection(ObjFile<ELF32BE> &, const ELF32BE::Shdr &,
                                    StringRef);
template InputSection::InputSection(ObjFile<ELF64LE> &, const ELF64LE::Shdr &,
                                    StringRef);
template InputSection::InputSection(ObjFile<ELF64BE> &, const ELF64BE::Shdr &,
                                    StringRef);

template std::string InputSectionBase::getLocation<ELF32LE>(uint64_t);
template std::string InputSectionBase::getLocation<ELF32BE>(uint64_t);
template std::string InputSectionBase::getLocation<ELF64LE>(uint64_t);
template std::string InputSectionBase::getLocation<ELF64BE>(uint64_t);

template void InputSection::writeTo<ELF32LE>(uint8_t *);
template void InputSection::writeTo<ELF32BE>(uint8_t *);
template void InputSection::writeTo<ELF64LE>(uint8_t *);
template void InputSection::writeTo<ELF64BE>(uint8_t *);

template MergeInputSection::MergeInputSection(ObjFile<ELF32LE> &,
                                              const ELF32LE::Shdr &, StringRef);
template MergeInputSection::MergeInputSection(ObjFile<ELF32BE> &,
                                              const ELF32BE::Shdr &, StringRef);
template MergeInputSection::MergeInputSection(ObjFile<ELF64LE> &,
                                              const ELF64LE::Shdr &, StringRef);
template MergeInputSection::MergeInputSection(ObjFile<ELF64BE> &,
                                              const ELF64BE::Shdr &, StringRef);

template EhInputSection::EhInputSection(ObjFile<ELF32LE> &,
                                        const ELF32LE::Shdr &, StringRef);
template EhInputSection::EhInputSection(ObjFile<ELF32BE> &,
                                        const ELF32BE::Shdr &, StringRef);
template EhInputSection::EhInputSection(ObjFile<ELF64LE> &,
                                        const ELF64LE::Shdr &, StringRef);
template EhInputSection::EhInputSection(ObjFile<ELF64BE> &,
                                        const ELF64BE::Shdr &, StringRef);

template void EhInputSection::split<ELF32LE>();
template void EhInputSection::split<ELF32BE>();
template void EhInputSection::split<ELF64LE>();
template void EhInputSection::split<ELF64BE>();
