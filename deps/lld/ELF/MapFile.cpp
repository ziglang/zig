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
#include "Symbols.h"
#include "SyntheticSections.h"
#include "lld/Common/Threads.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;
using namespace llvm::object;

using namespace lld;
using namespace lld::elf;

typedef DenseMap<const SectionBase *, SmallVector<Symbol *, 4>> SymbolMapTy;

// Print out the first three columns of a line.
static void writeHeader(raw_ostream &OS, uint64_t Addr, uint64_t Size,
                        uint64_t Align) {
  int W = Config->Is64 ? 16 : 8;
  OS << format("%0*llx %0*llx %5lld ", W, Addr, W, Size, Align);
}

static std::string indent(int Depth) { return std::string(Depth * 8, ' '); }

// Returns a list of all symbols that we want to print out.
static std::vector<Symbol *> getSymbols() {
  std::vector<Symbol *> V;
  for (InputFile *File : ObjectFiles) {
    for (Symbol *B : File->getSymbols()) {
      if (auto *SS = dyn_cast<SharedSymbol>(B))
        if (SS->CopyRelSec || SS->NeedsPltAddr)
          V.push_back(SS);
      if (auto *DR = dyn_cast<Defined>(B))
        if (DR->File == File && !DR->isSection() && DR->Section &&
            DR->Section->Live)
          V.push_back(DR);
    }
  }
  return V;
}

// Returns a map from sections to their symbols.
static SymbolMapTy getSectionSyms(ArrayRef<Symbol *> Syms) {
  SymbolMapTy Ret;
  for (Symbol *S : Syms) {
    if (auto *DR = dyn_cast<Defined>(S)) {
      Ret[DR->Section].push_back(S);
      continue;
    }

    SharedSymbol *SS = cast<SharedSymbol>(S);
    if (SS->CopyRelSec)
      Ret[SS->CopyRelSec].push_back(S);
    else
      Ret[InX::Plt].push_back(S);
  }

  // Sort symbols by address. We want to print out symbols in the
  // order in the output file rather than the order they appeared
  // in the input files.
  for (auto &It : Ret) {
    SmallVectorImpl<Symbol *> &V = It.second;
    std::sort(V.begin(), V.end(),
              [](Symbol *A, Symbol *B) { return A->getVA() < B->getVA(); });
  }
  return Ret;
}

// Construct a map from symbols to their stringified representations.
// Demangling symbols (which is what toString() does) is slow, so
// we do that in batch using parallel-for.
static DenseMap<Symbol *, std::string>
getSymbolStrings(ArrayRef<Symbol *> Syms) {
  std::vector<std::string> Str(Syms.size());
  parallelForEachN(0, Syms.size(), [&](size_t I) {
    raw_string_ostream OS(Str[I]);
    writeHeader(OS, Syms[I]->getVA(), Syms[I]->getSize(), 0);
    OS << indent(2) << toString(*Syms[I]);
  });

  DenseMap<Symbol *, std::string> Ret;
  for (size_t I = 0, E = Syms.size(); I < E; ++I)
    Ret[Syms[I]] = std::move(Str[I]);
  return Ret;
}

void elf::writeMapFile() {
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
  std::vector<Symbol *> Syms = getSymbols();
  SymbolMapTy SectionSyms = getSectionSyms(Syms);
  DenseMap<Symbol *, std::string> SymStr = getSymbolStrings(Syms);

  // Print out the header line.
  int W = Config->Is64 ? 16 : 8;
  OS << left_justify("Address", W) << ' ' << left_justify("Size", W)
     << " Align Out     In      Symbol\n";

  // Print out file contents.
  for (OutputSection *OSec : OutputSections) {
    writeHeader(OS, OSec->Addr, OSec->Size, OSec->Alignment);
    OS << OSec->Name << '\n';

    // Dump symbols for each input section.
    for (BaseCommand *Base : OSec->SectionCommands) {
      auto *ISD = dyn_cast<InputSectionDescription>(Base);
      if (!ISD)
        continue;
      for (InputSection *IS : ISD->Sections) {
        writeHeader(OS, OSec->Addr + IS->OutSecOff, IS->getSize(),
                    IS->Alignment);
        OS << indent(1) << toString(IS) << '\n';
        for (Symbol *Sym : SectionSyms[IS])
          OS << SymStr[Sym] << '\n';
      }
    }
  }
}
