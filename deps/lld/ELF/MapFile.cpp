//===- MapFile.cpp --------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file implements the -Map option. It shows lists in order and
// hierarchically the output sections, input sections, input files and
// symbol:
//
//   Address  Size     Align Out     In      Symbol
//   00201000 00000015     4 .text
//   00201000 0000000e     4         test.o:(.text)
//   0020100e 00000000     0                 local
//   00201005 00000000     0                 f(int)
//
//===----------------------------------------------------------------------===//

#include "MapFile.h"
#include "InputFiles.h"
#include "LinkerScript.h"
#include "OutputSections.h"
#include "Strings.h"
#include "SymbolTable.h"
#include "Threads.h"

#include "llvm/Support/raw_ostream.h"

using namespace llvm;
using namespace llvm::object;

using namespace lld;
using namespace lld::elf;

typedef DenseMap<const SectionBase *, SmallVector<DefinedRegular *, 4>>
    SymbolMapTy;

// Print out the first three columns of a line.
template <class ELFT>
static void writeHeader(raw_ostream &OS, uint64_t Addr, uint64_t Size,
                        uint64_t Align) {
  int W = ELFT::Is64Bits ? 16 : 8;
  OS << format("%0*llx %0*llx %5lld ", W, Addr, W, Size, Align);
}

static std::string indent(int Depth) { return std::string(Depth * 8, ' '); }

// Returns a list of all symbols that we want to print out.
template <class ELFT> std::vector<DefinedRegular *> getSymbols() {
  std::vector<DefinedRegular *> V;
  for (elf::ObjectFile<ELFT> *File : Symtab<ELFT>::X->getObjectFiles())
    for (SymbolBody *B : File->getSymbols())
      if (B->File == File && !B->isSection())
        if (auto *Sym = dyn_cast<DefinedRegular>(B))
          if (Sym->Section && Sym->Section->Live)
            V.push_back(Sym);
  return V;
}

// Returns a map from sections to their symbols.
template <class ELFT>
SymbolMapTy getSectionSyms(ArrayRef<DefinedRegular *> Syms) {
  SymbolMapTy Ret;
  for (DefinedRegular *S : Syms)
    Ret[S->Section].push_back(S);

  // Sort symbols by address. We want to print out symbols in the
  // order in the output file rather than the order they appeared
  // in the input files.
  for (auto &It : Ret) {
    SmallVectorImpl<DefinedRegular *> &V = It.second;
    std::sort(V.begin(), V.end(), [](DefinedRegular *A, DefinedRegular *B) {
      return A->getVA() < B->getVA();
    });
  }
  return Ret;
}

// Construct a map from symbols to their stringified representations.
// Demangling symbols (which is what toString() does) is slow, so
// we do that in batch using parallel-for.
template <class ELFT>
DenseMap<DefinedRegular *, std::string>
getSymbolStrings(ArrayRef<DefinedRegular *> Syms) {
  std::vector<std::string> Str(Syms.size());
  parallelForEachN(0, Syms.size(), [&](size_t I) {
    raw_string_ostream OS(Str[I]);
    writeHeader<ELFT>(OS, Syms[I]->getVA(), Syms[I]->template getSize<ELFT>(),
                      0);
    OS << indent(2) << toString(*Syms[I]);
  });

  DenseMap<DefinedRegular *, std::string> Ret;
  for (size_t I = 0, E = Syms.size(); I < E; ++I)
    Ret[Syms[I]] = std::move(Str[I]);
  return Ret;
}

template <class ELFT>
void elf::writeMapFile(llvm::ArrayRef<OutputSectionCommand *> Script) {
  if (Config->MapFile.empty())
    return;

  // Open a map file for writing.
  std::error_code EC;
  raw_fd_ostream OS(Config->MapFile, EC, sys::fs::F_None);
  if (EC) {
    error("cannot open " + Config->MapFile + ": " + EC.message());
    return;
  }

  // Collect symbol info that we want to print out.
  std::vector<DefinedRegular *> Syms = getSymbols<ELFT>();
  SymbolMapTy SectionSyms = getSectionSyms<ELFT>(Syms);
  DenseMap<DefinedRegular *, std::string> SymStr = getSymbolStrings<ELFT>(Syms);

  // Print out the header line.
  int W = ELFT::Is64Bits ? 16 : 8;
  OS << left_justify("Address", W) << ' ' << left_justify("Size", W)
     << " Align Out     In      Symbol\n";

  // Print out file contents.
  for (OutputSectionCommand *Cmd : Script) {
    OutputSection *OSec = Cmd->Sec;
    writeHeader<ELFT>(OS, OSec->Addr, OSec->Size, OSec->Alignment);
    OS << OSec->Name << '\n';

    // Dump symbols for each input section.
    for (BaseCommand *Base : Cmd->Commands) {
      auto *ISD = dyn_cast<InputSectionDescription>(Base);
      if (!ISD)
        continue;
      for (InputSection *IS : ISD->Sections) {
        writeHeader<ELFT>(OS, OSec->Addr + IS->OutSecOff, IS->getSize(),
                          IS->Alignment);
        OS << indent(1) << toString(IS) << '\n';
        for (DefinedRegular *Sym : SectionSyms[IS])
          OS << SymStr[Sym] << '\n';
      }
    }
  }
}

template void elf::writeMapFile<ELF32LE>(ArrayRef<OutputSectionCommand *>);
template void elf::writeMapFile<ELF32BE>(ArrayRef<OutputSectionCommand *>);
template void elf::writeMapFile<ELF64LE>(ArrayRef<OutputSectionCommand *>);
template void elf::writeMapFile<ELF64BE>(ArrayRef<OutputSectionCommand *>);
