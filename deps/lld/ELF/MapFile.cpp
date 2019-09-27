//===- MapFile.cpp --------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
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
#include "SymbolTable.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "lld/Common/Strings.h"
#include "lld/Common/Threads.h"
#include "llvm/ADT/MapVector.h"
#include "llvm/ADT/SetVector.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;
using namespace llvm::object;

using namespace lld;
using namespace lld::elf;

using SymbolMapTy = DenseMap<const SectionBase *, SmallVector<Defined *, 4>>;

static const std::string indent8 = "        ";          // 8 spaces
static const std::string indent16 = "                "; // 16 spaces

// Print out the first three columns of a line.
static void writeHeader(raw_ostream &os, uint64_t vma, uint64_t lma,
                        uint64_t size, uint64_t align) {
  if (config->is64)
    os << format("%16llx %16llx %8llx %5lld ", vma, lma, size, align);
  else
    os << format("%8llx %8llx %8llx %5lld ", vma, lma, size, align);
}

// Returns a list of all symbols that we want to print out.
static std::vector<Defined *> getSymbols() {
  std::vector<Defined *> v;
  for (InputFile *file : objectFiles)
    for (Symbol *b : file->getSymbols())
      if (auto *dr = dyn_cast<Defined>(b))
        if (!dr->isSection() && dr->section && dr->section->isLive() &&
            (dr->file == file || dr->needsPltAddr || dr->section->bss))
          v.push_back(dr);
  return v;
}

// Returns a map from sections to their symbols.
static SymbolMapTy getSectionSyms(ArrayRef<Defined *> syms) {
  SymbolMapTy ret;
  for (Defined *dr : syms)
    ret[dr->section].push_back(dr);

  // Sort symbols by address. We want to print out symbols in the
  // order in the output file rather than the order they appeared
  // in the input files.
  for (auto &it : ret)
    llvm::stable_sort(it.second, [](Defined *a, Defined *b) {
      return a->getVA() < b->getVA();
    });
  return ret;
}

// Construct a map from symbols to their stringified representations.
// Demangling symbols (which is what toString() does) is slow, so
// we do that in batch using parallel-for.
static DenseMap<Symbol *, std::string>
getSymbolStrings(ArrayRef<Defined *> syms) {
  std::vector<std::string> str(syms.size());
  parallelForEachN(0, syms.size(), [&](size_t i) {
    raw_string_ostream os(str[i]);
    OutputSection *osec = syms[i]->getOutputSection();
    uint64_t vma = syms[i]->getVA();
    uint64_t lma = osec ? osec->getLMA() + vma - osec->getVA(0) : 0;
    writeHeader(os, vma, lma, syms[i]->getSize(), 1);
    os << indent16 << toString(*syms[i]);
  });

  DenseMap<Symbol *, std::string> ret;
  for (size_t i = 0, e = syms.size(); i < e; ++i)
    ret[syms[i]] = std::move(str[i]);
  return ret;
}

// Print .eh_frame contents. Since the section consists of EhSectionPieces,
// we need a specialized printer for that section.
//
// .eh_frame tend to contain a lot of section pieces that are contiguous
// both in input file and output file. Such pieces are squashed before
// being displayed to make output compact.
static void printEhFrame(raw_ostream &os, const EhFrameSection *sec) {
  std::vector<EhSectionPiece> pieces;

  auto add = [&](const EhSectionPiece &p) {
    // If P is adjacent to Last, squash the two.
    if (!pieces.empty()) {
      EhSectionPiece &last = pieces.back();
      if (last.sec == p.sec && last.inputOff + last.size == p.inputOff &&
          last.outputOff + last.size == p.outputOff) {
        last.size += p.size;
        return;
      }
    }
    pieces.push_back(p);
  };

  // Gather section pieces.
  for (const CieRecord *rec : sec->getCieRecords()) {
    add(*rec->cie);
    for (const EhSectionPiece *fde : rec->fdes)
      add(*fde);
  }

  // Print out section pieces.
  const OutputSection *osec = sec->getOutputSection();
  for (EhSectionPiece &p : pieces) {
    writeHeader(os, osec->addr + p.outputOff, osec->getLMA() + p.outputOff,
                p.size, 1);
    os << indent8 << toString(p.sec->file) << ":(" << p.sec->name << "+0x"
       << Twine::utohexstr(p.inputOff) + ")\n";
  }
}

void elf::writeMapFile() {
  if (config->mapFile.empty())
    return;

  // Open a map file for writing.
  std::error_code ec;
  raw_fd_ostream os(config->mapFile, ec, sys::fs::F_None);
  if (ec) {
    error("cannot open " + config->mapFile + ": " + ec.message());
    return;
  }

  // Collect symbol info that we want to print out.
  std::vector<Defined *> syms = getSymbols();
  SymbolMapTy sectionSyms = getSectionSyms(syms);
  DenseMap<Symbol *, std::string> symStr = getSymbolStrings(syms);

  // Print out the header line.
  int w = config->is64 ? 16 : 8;
  os << right_justify("VMA", w) << ' ' << right_justify("LMA", w)
     << "     Size Align Out     In      Symbol\n";

  OutputSection* osec = nullptr;
  for (BaseCommand *base : script->sectionCommands) {
    if (auto *cmd = dyn_cast<SymbolAssignment>(base)) {
      if (cmd->provide && !cmd->sym)
        continue;
      uint64_t lma = osec ? osec->getLMA() + cmd->addr - osec->getVA(0) : 0;
      writeHeader(os, cmd->addr, lma, cmd->size, 1);
      os << cmd->commandString << '\n';
      continue;
    }

    osec = cast<OutputSection>(base);
    writeHeader(os, osec->addr, osec->getLMA(), osec->size, osec->alignment);
    os << osec->name << '\n';

    // Dump symbols for each input section.
    for (BaseCommand *base : osec->sectionCommands) {
      if (auto *isd = dyn_cast<InputSectionDescription>(base)) {
        for (InputSection *isec : isd->sections) {
          if (auto *ehSec = dyn_cast<EhFrameSection>(isec)) {
            printEhFrame(os, ehSec);
            continue;
          }

          writeHeader(os, isec->getVA(0), osec->getLMA() + isec->getOffset(0),
                      isec->getSize(), isec->alignment);
          os << indent8 << toString(isec) << '\n';
          for (Symbol *sym : sectionSyms[isec])
            os << symStr[sym] << '\n';
        }
        continue;
      }

      if (auto *cmd = dyn_cast<ByteCommand>(base)) {
        writeHeader(os, osec->addr + cmd->offset, osec->getLMA() + cmd->offset,
                    cmd->size, 1);
        os << indent8 << cmd->commandString << '\n';
        continue;
      }

      if (auto *cmd = dyn_cast<SymbolAssignment>(base)) {
        if (cmd->provide && !cmd->sym)
          continue;
        writeHeader(os, cmd->addr, osec->getLMA() + cmd->addr - osec->getVA(0),
                    cmd->size, 1);
        os << indent8 << cmd->commandString << '\n';
        continue;
      }
    }
  }
}

static void print(StringRef a, StringRef b) {
  outs() << left_justify(a, 49) << " " << b << "\n";
}

// Output a cross reference table to stdout. This is for --cref.
//
// For each global symbol, we print out a file that defines the symbol
// followed by files that uses that symbol. Here is an example.
//
//     strlen     /lib/x86_64-linux-gnu/libc.so.6
//                tools/lld/tools/lld/CMakeFiles/lld.dir/lld.cpp.o
//                lib/libLLVMSupport.a(PrettyStackTrace.cpp.o)
//
// In this case, strlen is defined by libc.so.6 and used by other two
// files.
void elf::writeCrossReferenceTable() {
  if (!config->cref)
    return;

  // Collect symbols and files.
  MapVector<Symbol *, SetVector<InputFile *>> map;
  for (InputFile *file : objectFiles) {
    for (Symbol *sym : file->getSymbols()) {
      if (isa<SharedSymbol>(sym))
        map[sym].insert(file);
      if (auto *d = dyn_cast<Defined>(sym))
        if (!d->isLocal() && (!d->section || d->section->isLive()))
          map[d].insert(file);
    }
  }

  // Print out a header.
  outs() << "Cross Reference Table\n\n";
  print("Symbol", "File");

  // Print out a table.
  for (auto kv : map) {
    Symbol *sym = kv.first;
    SetVector<InputFile *> &files = kv.second;

    print(toString(*sym), toString(sym->file));
    for (InputFile *file : files)
      if (file != sym->file)
        print("", toString(file));
  }
}
