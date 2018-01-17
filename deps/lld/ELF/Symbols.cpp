//===- Symbols.cpp --------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "Symbols.h"
#include "InputFiles.h"
#include "InputSection.h"
#include "OutputSections.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "Writer.h"

#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Strings.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/Support/Path.h"
#include <cstring>

using namespace llvm;
using namespace llvm::object;
using namespace llvm::ELF;

using namespace lld;
using namespace lld::elf;

Defined *ElfSym::Bss;
Defined *ElfSym::Etext1;
Defined *ElfSym::Etext2;
Defined *ElfSym::Edata1;
Defined *ElfSym::Edata2;
Defined *ElfSym::End1;
Defined *ElfSym::End2;
Defined *ElfSym::GlobalOffsetTable;
Defined *ElfSym::MipsGp;
Defined *ElfSym::MipsGpDisp;
Defined *ElfSym::MipsLocalGp;

static uint64_t getSymVA(const Symbol &Sym, int64_t &Addend) {
  switch (Sym.kind()) {
  case Symbol::DefinedKind: {
    auto &D = cast<Defined>(Sym);
    SectionBase *IS = D.Section;

    // According to the ELF spec reference to a local symbol from outside
    // the group are not allowed. Unfortunately .eh_frame breaks that rule
    // and must be treated specially. For now we just replace the symbol with
    // 0.
    if (IS == &InputSection::Discarded)
      return 0;

    // This is an absolute symbol.
    if (!IS)
      return D.Value;

    IS = IS->Repl;
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
  case Symbol::SharedKind: {
    auto &SS = cast<SharedSymbol>(Sym);
    if (SS.CopyRelSec)
      return SS.CopyRelSec->getParent()->Addr + SS.CopyRelSec->OutSecOff;
    if (SS.NeedsPltAddr)
      return Sym.getPltVA();
    return 0;
  }
  case Symbol::UndefinedKind:
    return 0;
  case Symbol::LazyArchiveKind:
  case Symbol::LazyObjectKind:
    assert(Sym.IsUsedInRegularObj && "lazy symbol reached writer");
    return 0;
  }
  llvm_unreachable("invalid symbol kind");
}

uint64_t Symbol::getVA(int64_t Addend) const {
  uint64_t OutVA = getSymVA(*this, Addend);
  return OutVA + Addend;
}

uint64_t Symbol::getGotVA() const { return InX::Got->getVA() + getGotOffset(); }

uint64_t Symbol::getGotOffset() const {
  return GotIndex * Target->GotEntrySize;
}

uint64_t Symbol::getGotPltVA() const {
  if (this->IsInIgot)
    return InX::IgotPlt->getVA() + getGotPltOffset();
  return InX::GotPlt->getVA() + getGotPltOffset();
}

uint64_t Symbol::getGotPltOffset() const {
  return GotPltIndex * Target->GotPltEntrySize;
}

uint64_t Symbol::getPltVA() const {
  if (this->IsInIplt)
    return InX::Iplt->getVA() + PltIndex * Target->PltEntrySize;
  return InX::Plt->getVA() + Target->PltHeaderSize +
         PltIndex * Target->PltEntrySize;
}

uint64_t Symbol::getSize() const {
  if (const auto *DR = dyn_cast<Defined>(this))
    return DR->Size;
  if (const auto *S = dyn_cast<SharedSymbol>(this))
    return S->Size;
  return 0;
}

OutputSection *Symbol::getOutputSection() const {
  if (auto *S = dyn_cast<Defined>(this)) {
    if (auto *Sec = S->Section)
      return Sec->Repl->getOutputSection();
    return nullptr;
  }

  if (auto *S = dyn_cast<SharedSymbol>(this)) {
    if (S->CopyRelSec)
      return S->CopyRelSec->getParent();
    return nullptr;
  }

  return nullptr;
}

// If a symbol name contains '@', the characters after that is
// a symbol version name. This function parses that.
void Symbol::parseSymbolVersion() {
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
  if (!isDefined())
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
      VersionId = Ver.Id;
    else
      VersionId = Ver.Id | VERSYM_HIDDEN;
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

InputFile *Lazy::fetch() {
  if (auto *S = dyn_cast<LazyArchive>(this))
    return S->fetch();
  return cast<LazyObject>(this)->fetch();
}

ArchiveFile &LazyArchive::getFile() { return *cast<ArchiveFile>(File); }

InputFile *LazyArchive::fetch() {
  std::pair<MemoryBufferRef, uint64_t> MBInfo = getFile().getMember(&Sym);

  // getMember returns an empty buffer if the member was already
  // read from the library.
  if (MBInfo.first.getBuffer().empty())
    return nullptr;
  return createObjectFile(MBInfo.first, getFile().getName(), MBInfo.second);
}

LazyObjFile &LazyObject::getFile() { return *cast<LazyObjFile>(File); }

InputFile *LazyObject::fetch() { return getFile().fetch(); }

uint8_t Symbol::computeBinding() const {
  if (Config->Relocatable)
    return Binding;
  if (Visibility != STV_DEFAULT && Visibility != STV_PROTECTED)
    return STB_LOCAL;
  if (VersionId == VER_NDX_LOCAL && isDefined())
    return STB_LOCAL;
  if (Config->NoGnuUnique && Binding == STB_GNU_UNIQUE)
    return STB_GLOBAL;
  return Binding;
}

bool Symbol::includeInDynsym() const {
  if (!Config->HasDynSymTab)
    return false;
  if (computeBinding() == STB_LOCAL)
    return false;
  if (!isDefined())
    return true;
  return ExportDynamic;
}

// Print out a log message for --trace-symbol.
void elf::printTraceSymbol(Symbol *Sym) {
  std::string S;
  if (Sym->isUndefined())
    S = ": reference to ";
  else if (Sym->isLazy())
    S = ": lazy definition of ";
  else if (Sym->isShared())
    S = ": shared definition of ";
  else if (dyn_cast_or_null<BssSection>(cast<Defined>(Sym)->Section))
    S = ": common definition of ";
  else
    S = ": definition of ";

  message(toString(Sym->File) + S + Sym->getName());
}

// Returns a symbol for an error message.
std::string lld::toString(const Symbol &B) {
  if (Config->Demangle)
    if (Optional<std::string> S = demangleItanium(B.getName()))
      return *S;
  return B.getName();
}
