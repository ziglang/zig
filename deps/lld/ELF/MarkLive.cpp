//===- MarkLive.cpp -------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file implements --gc-sections, which is a feature to remove unused
// sections from output. Unused sections are sections that are not reachable
// from known GC-root symbols or sections. Naturally the feature is
// implemented as a mark-sweep garbage collector.
//
// Here's how it works. Each InputSectionBase has a "Live" bit. The bit is off
// by default. Starting with GC-root symbols or sections, markLive function
// defined in this file visits all reachable sections to set their Live
// bits. Writer will then ignore sections whose Live bits are off, so that
// such sections are not included into output.
//
//===----------------------------------------------------------------------===//

#include "InputSection.h"
#include "LinkerScript.h"
#include "Memory.h"
#include "OutputSections.h"
#include "Strings.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "Target.h"
#include "Writer.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/Object/ELF.h"
#include <functional>
#include <vector>

using namespace llvm;
using namespace llvm::ELF;
using namespace llvm::object;
using namespace llvm::support::endian;

using namespace lld;
using namespace lld::elf;

namespace {
// A resolved relocation. The Sec and Offset fields are set if the relocation
// was resolved to an offset within a section.
struct ResolvedReloc {
  InputSectionBase *Sec;
  uint64_t Offset;
};
} // end anonymous namespace

template <class ELFT>
static typename ELFT::uint getAddend(InputSectionBase &Sec,
                                     const typename ELFT::Rel &Rel) {
  return Target->getImplicitAddend(Sec.Data.begin() + Rel.r_offset,
                                   Rel.getType(Config->IsMips64EL));
}

template <class ELFT>
static typename ELFT::uint getAddend(InputSectionBase &Sec,
                                     const typename ELFT::Rela &Rel) {
  return Rel.r_addend;
}

// There are normally few input sections whose names are valid C
// identifiers, so we just store a std::vector instead of a multimap.
static DenseMap<StringRef, std::vector<InputSectionBase *>> CNamedSections;

template <class ELFT, class RelT>
static void resolveReloc(InputSectionBase &Sec, RelT &Rel,
                         std::function<void(ResolvedReloc)> Fn) {
  SymbolBody &B = Sec.getFile<ELFT>()->getRelocTargetSym(Rel);
  if (auto *D = dyn_cast<DefinedRegular>(&B)) {
    if (!D->Section)
      return;
    typename ELFT::uint Offset = D->Value;
    if (D->isSection())
      Offset += getAddend<ELFT>(Sec, Rel);
    Fn({cast<InputSectionBase>(D->Section), Offset});
  } else if (auto *U = dyn_cast<Undefined>(&B)) {
    for (InputSectionBase *Sec : CNamedSections.lookup(U->getName()))
      Fn({Sec, 0});
  }
}

// Calls Fn for each section that Sec refers to via relocations.
template <class ELFT>
static void forEachSuccessor(InputSection &Sec,
                             std::function<void(ResolvedReloc)> Fn) {
  if (Sec.AreRelocsRela) {
    for (const typename ELFT::Rela &Rel : Sec.template relas<ELFT>())
      resolveReloc<ELFT>(Sec, Rel, Fn);
  } else {
    for (const typename ELFT::Rel &Rel : Sec.template rels<ELFT>())
      resolveReloc<ELFT>(Sec, Rel, Fn);
  }
  for (InputSectionBase *IS : Sec.DependentSections)
    Fn({IS, 0});
}

// The .eh_frame section is an unfortunate special case.
// The section is divided in CIEs and FDEs and the relocations it can have are
// * CIEs can refer to a personality function.
// * FDEs can refer to a LSDA
// * FDEs refer to the function they contain information about
// The last kind of relocation cannot keep the referred section alive, or they
// would keep everything alive in a common object file. In fact, each FDE is
// alive if the section it refers to is alive.
// To keep things simple, in here we just ignore the last relocation kind. The
// other two keep the referred section alive.
//
// A possible improvement would be to fully process .eh_frame in the middle of
// the gc pass. With that we would be able to also gc some sections holding
// LSDAs and personality functions if we found that they were unused.
template <class ELFT, class RelTy>
static void scanEhFrameSection(EhInputSection &EH, ArrayRef<RelTy> Rels,
                               std::function<void(ResolvedReloc)> Enqueue) {
  const endianness E = ELFT::TargetEndianness;
  for (unsigned I = 0, N = EH.Pieces.size(); I < N; ++I) {
    EhSectionPiece &Piece = EH.Pieces[I];
    unsigned FirstRelI = Piece.FirstRelocation;
    if (FirstRelI == (unsigned)-1)
      continue;
    if (read32<E>(Piece.data().data() + 4) == 0) {
      // This is a CIE, we only need to worry about the first relocation. It is
      // known to point to the personality function.
      resolveReloc<ELFT>(EH, Rels[FirstRelI], Enqueue);
      continue;
    }
    // This is a FDE. The relocations point to the described function or to
    // a LSDA. We only need to keep the LSDA alive, so ignore anything that
    // points to executable sections.
    typename ELFT::uint PieceEnd = Piece.InputOff + Piece.size();
    for (unsigned I2 = FirstRelI, N2 = Rels.size(); I2 < N2; ++I2) {
      const RelTy &Rel = Rels[I2];
      if (Rel.r_offset >= PieceEnd)
        break;
      resolveReloc<ELFT>(EH, Rels[I2], [&](ResolvedReloc R) {
        if (!R.Sec || R.Sec == &InputSection::Discarded)
          return;
        if (R.Sec->Flags & SHF_EXECINSTR)
          return;
        Enqueue({R.Sec, 0});
      });
    }
  }
}

template <class ELFT>
static void scanEhFrameSection(EhInputSection &EH,
                               std::function<void(ResolvedReloc)> Enqueue) {
  if (!EH.NumRelocations)
    return;

  // Unfortunately we need to split .eh_frame early since some relocations in
  // .eh_frame keep other section alive and some don't.
  EH.split<ELFT>();

  if (EH.AreRelocsRela)
    scanEhFrameSection<ELFT>(EH, EH.template relas<ELFT>(), Enqueue);
  else
    scanEhFrameSection<ELFT>(EH, EH.template rels<ELFT>(), Enqueue);
}

// We do not garbage-collect two types of sections:
// 1) Sections used by the loader (.init, .fini, .ctors, .dtors or .jcr)
// 2) Non-allocatable sections which typically contain debugging information
template <class ELFT> static bool isReserved(InputSectionBase *Sec) {
  switch (Sec->Type) {
  case SHT_FINI_ARRAY:
  case SHT_INIT_ARRAY:
  case SHT_NOTE:
  case SHT_PREINIT_ARRAY:
    return true;
  default:
    if (!(Sec->Flags & SHF_ALLOC))
      return true;

    StringRef S = Sec->Name;
    return S.startswith(".ctors") || S.startswith(".dtors") ||
           S.startswith(".init") || S.startswith(".fini") ||
           S.startswith(".jcr");
  }
}

// This is the main function of the garbage collector.
// Starting from GC-root sections, this function visits all reachable
// sections to set their "Live" bits.
template <class ELFT> void elf::markLive() {
  SmallVector<InputSection *, 256> Q;
  CNamedSections.clear();

  auto Enqueue = [&](ResolvedReloc R) {
    // Skip over discarded sections. This in theory shouldn't happen, because
    // the ELF spec doesn't allow a relocation to point to a deduplicated
    // COMDAT section directly. Unfortunately this happens in practice (e.g.
    // .eh_frame) so we need to add a check.
    if (R.Sec == &InputSection::Discarded)
      return;

    // We don't gc non alloc sections.
    if (!(R.Sec->Flags & SHF_ALLOC))
      return;

    // Usually, a whole section is marked as live or dead, but in mergeable
    // (splittable) sections, each piece of data has independent liveness bit.
    // So we explicitly tell it which offset is in use.
    if (auto *MS = dyn_cast<MergeInputSection>(R.Sec))
      MS->markLiveAt(R.Offset);

    if (R.Sec->Live)
      return;
    R.Sec->Live = true;
    // Add input section to the queue.
    if (InputSection *S = dyn_cast<InputSection>(R.Sec))
      Q.push_back(S);
  };

  auto MarkSymbol = [&](const SymbolBody *Sym) {
    if (auto *D = dyn_cast_or_null<DefinedRegular>(Sym))
      if (auto *IS = cast_or_null<InputSectionBase>(D->Section))
        Enqueue({IS, D->Value});
  };

  // Add GC root symbols.
  MarkSymbol(Symtab<ELFT>::X->find(Config->Entry));
  MarkSymbol(Symtab<ELFT>::X->find(Config->Init));
  MarkSymbol(Symtab<ELFT>::X->find(Config->Fini));
  for (StringRef S : Config->Undefined)
    MarkSymbol(Symtab<ELFT>::X->find(S));
  for (StringRef S : Script->Opt.ReferencedSymbols)
    MarkSymbol(Symtab<ELFT>::X->find(S));

  // Preserve externally-visible symbols if the symbols defined by this
  // file can interrupt other ELF file's symbols at runtime.
  for (const Symbol *S : Symtab<ELFT>::X->getSymbols())
    if (S->includeInDynsym())
      MarkSymbol(S->body());

  // Preserve special sections and those which are specified in linker
  // script KEEP command.
  for (InputSectionBase *Sec : InputSections) {
    // .eh_frame is always marked as live now, but also it can reference to
    // sections that contain personality. We preserve all non-text sections
    // referred by .eh_frame here.
    if (auto *EH = dyn_cast_or_null<EhInputSection>(Sec))
      scanEhFrameSection<ELFT>(*EH, Enqueue);
    if (Sec->Flags & SHF_LINK_ORDER)
      continue;
    if (isReserved<ELFT>(Sec) || Script->shouldKeep(Sec))
      Enqueue({Sec, 0});
    else if (isValidCIdentifier(Sec->Name)) {
      CNamedSections[Saver.save("__start_" + Sec->Name)].push_back(Sec);
      CNamedSections[Saver.save("__end_" + Sec->Name)].push_back(Sec);
    }
  }

  // Mark all reachable sections.
  while (!Q.empty())
    forEachSuccessor<ELFT>(*Q.pop_back_val(), Enqueue);
}

template void elf::markLive<ELF32LE>();
template void elf::markLive<ELF32BE>();
template void elf::markLive<ELF64LE>();
template void elf::markLive<ELF64BE>();
