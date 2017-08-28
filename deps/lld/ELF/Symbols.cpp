//===- Symbols.cpp --------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "Symbols.h"
#include "Error.h"
#include "InputFiles.h"
#include "InputSection.h"
#include "OutputSections.h"
#include "Strings.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "Writer.h"

#include "llvm/ADT/STLExtras.h"
#include "llvm/Support/Path.h"
#include <cstring>

using namespace llvm;
using namespace llvm::object;
using namespace llvm::ELF;

using namespace lld;
using namespace lld::elf;

DefinedRegular *ElfSym::Bss;
DefinedRegular *ElfSym::Etext1;
DefinedRegular *ElfSym::Etext2;
DefinedRegular *ElfSym::Edata1;
DefinedRegular *ElfSym::Edata2;
DefinedRegular *ElfSym::End1;
DefinedRegular *ElfSym::End2;
DefinedRegular *ElfSym::GlobalOffsetTable;
DefinedRegular *ElfSym::MipsGp;
DefinedRegular *ElfSym::MipsGpDisp;
DefinedRegular *ElfSym::MipsLocalGp;

static uint64_t getSymVA(const SymbolBody &Body, int64_t &Addend) {
  switch (Body.kind()) {
  case SymbolBody::DefinedRegularKind: {
    auto &D = cast<DefinedRegular>(Body);
    SectionBase *IS = D.Section;
    if (auto *ISB = dyn_cast_or_null<InputSectionBase>(IS))
      IS = ISB->Repl;

    // According to the ELF spec reference to a local symbol from outside
    // the group are not allowed. Unfortunately .eh_frame breaks that rule
    // and must be treated specially. For now we just replace the symbol with
    // 0.
    if (IS == &InputSection::Discarded)
      return 0;

    // This is an absolute symbol.
    if (!IS)
      return D.Value;

    uint64_t Offset = D.Value;

    // An object in an SHF_MERGE section might be referenced via a
    // section symbol (as a hack for reducing the number of local
    // symbols).
    // Depending on the addend, the reference via a section symbol
    // refers to a different object in the merge section.
    // Since the objects in the merge section are not necessarily
    // contiguous in the output, the addend can thus affect the final
    // VA in a non-linear way.
    // To make this work, we incorporate the addend into the section
    // offset (and zero out the addend for later processing) so that
    // we find the right object in the section.
    if (D.isSection()) {
      Offset += Addend;
      Addend = 0;
    }

    const OutputSection *OutSec = IS->getOutputSection();

    // In the typical case, this is actually very simple and boils
    // down to adding together 3 numbers:
    // 1. The address of the output section.
    // 2. The offset of the input section within the output section.
    // 3. The offset within the input section (this addition happens
    //    inside InputSection::getOffset).
    //
    // If you understand the data structures involved with this next
    // line (and how they get built), then you have a pretty good
    // understanding of the linker.
    uint64_t VA = (OutSec ? OutSec->Addr : 0) + IS->getOffset(Offset);

    if (D.isTls() && !Config->Relocatable) {
      if (!Out::TlsPhdr)
        fatal(toString(D.File) +
              " has an STT_TLS symbol but doesn't have an SHF_TLS section");
      return VA - Out::TlsPhdr->p_vaddr;
    }
    return VA;
  }
  case SymbolBody::DefinedCommonKind:
    if (!Config->DefineCommon)
      return 0;
    return InX::Common->getParent()->Addr + InX::Common->OutSecOff +
           cast<DefinedCommon>(Body).Offset;
  case SymbolBody::SharedKind: {
    auto &SS = cast<SharedSymbol>(Body);
    if (SS.NeedsCopy)
      return SS.CopyRelSec->getParent()->Addr + SS.CopyRelSec->OutSecOff +
             SS.CopyRelSecOff;
    if (SS.NeedsPltAddr)
      return Body.getPltVA();
    return 0;
  }
  case SymbolBody::UndefinedKind:
    return 0;
  case SymbolBody::LazyArchiveKind:
  case SymbolBody::LazyObjectKind:
    assert(Body.symbol()->IsUsedInRegularObj && "lazy symbol reached writer");
    return 0;
  }
  llvm_unreachable("invalid symbol kind");
}

SymbolBody::SymbolBody(Kind K, StringRefZ Name, bool IsLocal, uint8_t StOther,
                       uint8_t Type)
    : SymbolKind(K), NeedsCopy(false), NeedsPltAddr(false), IsLocal(IsLocal),
      IsInGlobalMipsGot(false), Is32BitMipsGot(false), IsInIplt(false),
      IsInIgot(false), Type(Type), StOther(StOther), Name(Name) {}

// Returns true if a symbol can be replaced at load-time by a symbol
// with the same name defined in other ELF executable or DSO.
bool SymbolBody::isPreemptible() const {
  if (isLocal())
    return false;

  // Shared symbols resolve to the definition in the DSO. The exceptions are
  // symbols with copy relocations (which resolve to .bss) or preempt plt
  // entries (which resolve to that plt entry).
  if (isShared())
    return !NeedsCopy && !NeedsPltAddr;

  // That's all that can be preempted in a non-DSO.
  if (!Config->Shared)
    return false;

  // Only symbols that appear in dynsym can be preempted.
  if (!symbol()->includeInDynsym())
    return false;

  // Only default visibility symbols can be preempted.
  if (symbol()->Visibility != STV_DEFAULT)
    return false;

  // -Bsymbolic means that definitions are not preempted.
  if (Config->Bsymbolic || (Config->BsymbolicFunctions && isFunc()))
    return !isDefined();
  return true;
}

// Overwrites all attributes with Other's so that this symbol becomes
// an alias to Other. This is useful for handling some options such as
// --wrap.
void SymbolBody::copy(SymbolBody *Other) {
  memcpy(symbol()->Body.buffer, Other->symbol()->Body.buffer,
         sizeof(Symbol::Body));
}

uint64_t SymbolBody::getVA(int64_t Addend) const {
  uint64_t OutVA = getSymVA(*this, Addend);
  return OutVA + Addend;
}

uint64_t SymbolBody::getGotVA() const {
  return InX::Got->getVA() + getGotOffset();
}

uint64_t SymbolBody::getGotOffset() const {
  return GotIndex * Target->GotEntrySize;
}

uint64_t SymbolBody::getGotPltVA() const {
  if (this->IsInIgot)
    return InX::IgotPlt->getVA() + getGotPltOffset();
  return InX::GotPlt->getVA() + getGotPltOffset();
}

uint64_t SymbolBody::getGotPltOffset() const {
  return GotPltIndex * Target->GotPltEntrySize;
}

uint64_t SymbolBody::getPltVA() const {
  if (this->IsInIplt)
    return InX::Iplt->getVA() + PltIndex * Target->PltEntrySize;
  return InX::Plt->getVA() + Target->PltHeaderSize +
         PltIndex * Target->PltEntrySize;
}

template <class ELFT> typename ELFT::uint SymbolBody::getSize() const {
  if (const auto *C = dyn_cast<DefinedCommon>(this))
    return C->Size;
  if (const auto *DR = dyn_cast<DefinedRegular>(this))
    return DR->Size;
  if (const auto *S = dyn_cast<SharedSymbol>(this))
    return S->getSize<ELFT>();
  return 0;
}

OutputSection *SymbolBody::getOutputSection() const {
  if (auto *S = dyn_cast<DefinedRegular>(this)) {
    if (S->Section)
      return S->Section->getOutputSection();
    return nullptr;
  }

  if (auto *S = dyn_cast<SharedSymbol>(this)) {
    if (S->NeedsCopy)
      return S->CopyRelSec->getParent();
    return nullptr;
  }

  if (isa<DefinedCommon>(this)) {
    if (Config->DefineCommon)
      return InX::Common->getParent();
    return nullptr;
  }

  return nullptr;
}

// If a symbol name contains '@', the characters after that is
// a symbol version name. This function parses that.
void SymbolBody::parseSymbolVersion() {
  StringRef S = getName();
  size_t Pos = S.find('@');
  if (Pos == 0 || Pos == StringRef::npos)
    return;
  StringRef Verstr = S.substr(Pos + 1);
  if (Verstr.empty())
    return;

  // Truncate the symbol name so that it doesn't include the version string.
  Name = {S.data(), Pos};

  // If this is not in this DSO, it is not a definition.
  if (!isInCurrentDSO())
    return;

  // '@@' in a symbol name means the default version.
  // It is usually the most recent one.
  bool IsDefault = (Verstr[0] == '@');
  if (IsDefault)
    Verstr = Verstr.substr(1);

  for (VersionDefinition &Ver : Config->VersionDefinitions) {
    if (Ver.Name != Verstr)
      continue;

    if (IsDefault)
      symbol()->VersionId = Ver.Id;
    else
      symbol()->VersionId = Ver.Id | VERSYM_HIDDEN;
    return;
  }

  // It is an error if the specified version is not defined.
  // Usually version script is not provided when linking executable,
  // but we may still want to override a versioned symbol from DSO,
  // so we do not report error in this case.
  if (Config->Shared)
    error(toString(File) + ": symbol " + S + " has undefined version " +
          Verstr);
}

Defined::Defined(Kind K, StringRefZ Name, bool IsLocal, uint8_t StOther,
                 uint8_t Type)
    : SymbolBody(K, Name, IsLocal, StOther, Type) {}

template <class ELFT> bool DefinedRegular::isMipsPIC() const {
  typedef typename ELFT::Ehdr Elf_Ehdr;
  if (!Section || !isFunc())
    return false;

  auto *Sec = cast<InputSectionBase>(Section);
  const Elf_Ehdr *Hdr = Sec->template getFile<ELFT>()->getObj().getHeader();
  return (this->StOther & STO_MIPS_MIPS16) == STO_MIPS_PIC ||
         (Hdr->e_flags & EF_MIPS_PIC);
}

Undefined::Undefined(StringRefZ Name, bool IsLocal, uint8_t StOther,
                     uint8_t Type, InputFile *File)
    : SymbolBody(SymbolBody::UndefinedKind, Name, IsLocal, StOther, Type) {
  this->File = File;
}

DefinedCommon::DefinedCommon(StringRef Name, uint64_t Size, uint32_t Alignment,
                             uint8_t StOther, uint8_t Type, InputFile *File)
    : Defined(SymbolBody::DefinedCommonKind, Name, /*IsLocal=*/false, StOther,
              Type),
      Alignment(Alignment), Size(Size) {
  this->File = File;
}

// If a shared symbol is referred via a copy relocation, its alignment
// becomes part of the ABI. This function returns a symbol alignment.
// Because symbols don't have alignment attributes, we need to infer that.
template <class ELFT> uint32_t SharedSymbol::getAlignment() const {
  auto *File = cast<SharedFile<ELFT>>(this->File);
  uint32_t SecAlign = File->getSection(getSym<ELFT>())->sh_addralign;
  uint64_t SymValue = getSym<ELFT>().st_value;
  uint32_t SymAlign = uint32_t(1) << countTrailingZeros(SymValue);
  return std::min(SecAlign, SymAlign);
}

InputFile *Lazy::fetch() {
  if (auto *S = dyn_cast<LazyArchive>(this))
    return S->fetch();
  return cast<LazyObject>(this)->fetch();
}

LazyArchive::LazyArchive(ArchiveFile &File,
                         const llvm::object::Archive::Symbol S, uint8_t Type)
    : Lazy(LazyArchiveKind, S.getName(), Type), Sym(S) {
  this->File = &File;
}

LazyObject::LazyObject(StringRef Name, LazyObjectFile &File, uint8_t Type)
    : Lazy(LazyObjectKind, Name, Type) {
  this->File = &File;
}

InputFile *LazyArchive::fetch() {
  std::pair<MemoryBufferRef, uint64_t> MBInfo = file()->getMember(&Sym);

  // getMember returns an empty buffer if the member was already
  // read from the library.
  if (MBInfo.first.getBuffer().empty())
    return nullptr;
  return createObjectFile(MBInfo.first, file()->getName(), MBInfo.second);
}

InputFile *LazyObject::fetch() { return file()->fetch(); }

uint8_t Symbol::computeBinding() const {
  if (Config->Relocatable)
    return Binding;
  if (Visibility != STV_DEFAULT && Visibility != STV_PROTECTED)
    return STB_LOCAL;
  if (VersionId == VER_NDX_LOCAL && body()->isInCurrentDSO())
    return STB_LOCAL;
  if (Config->NoGnuUnique && Binding == STB_GNU_UNIQUE)
    return STB_GLOBAL;
  return Binding;
}

bool Symbol::includeInDynsym() const {
  if (computeBinding() == STB_LOCAL)
    return false;
  return ExportDynamic || body()->isShared() ||
         (body()->isUndefined() && Config->Shared);
}

// Print out a log message for --trace-symbol.
void elf::printTraceSymbol(Symbol *Sym) {
  SymbolBody *B = Sym->body();
  std::string S;
  if (B->isUndefined())
    S = ": reference to ";
  else if (B->isCommon())
    S = ": common definition of ";
  else
    S = ": definition of ";

  message(toString(B->File) + S + B->getName());
}

// Returns a symbol for an error message.
std::string lld::toString(const SymbolBody &B) {
  if (Config->Demangle)
    if (Optional<std::string> S = demangle(B.getName()))
      return *S;
  return B.getName();
}

template uint32_t SymbolBody::template getSize<ELF32LE>() const;
template uint32_t SymbolBody::template getSize<ELF32BE>() const;
template uint64_t SymbolBody::template getSize<ELF64LE>() const;
template uint64_t SymbolBody::template getSize<ELF64BE>() const;

template bool DefinedRegular::template isMipsPIC<ELF32LE>() const;
template bool DefinedRegular::template isMipsPIC<ELF32BE>() const;
template bool DefinedRegular::template isMipsPIC<ELF64LE>() const;
template bool DefinedRegular::template isMipsPIC<ELF64BE>() const;

template uint32_t SharedSymbol::template getAlignment<ELF32LE>() const;
template uint32_t SharedSymbol::template getAlignment<ELF32BE>() const;
template uint32_t SharedSymbol::template getAlignment<ELF64LE>() const;
template uint32_t SharedSymbol::template getAlignment<ELF64BE>() const;
