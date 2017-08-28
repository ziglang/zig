//===- GdbIndex.cpp -------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// The -gdb-index option instructs the linker to emit a .gdb_index section.
// The section contains information to make gdb startup faster.
// The format of the section is described at
// https://sourceware.org/gdb/onlinedocs/gdb/Index-Section-Format.html.
//
//===----------------------------------------------------------------------===//

#include "GdbIndex.h"
#include "Memory.h"
#include "llvm/DebugInfo/DWARF/DWARFDebugPubTable.h"
#include "llvm/Object/ELFObjectFile.h"

using namespace llvm;
using namespace llvm::object;
using namespace lld;
using namespace lld::elf;

std::pair<bool, GdbSymbol *> GdbHashTab::add(uint32_t Hash, size_t Offset) {
  GdbSymbol *&Sym = Map[Offset];
  if (Sym)
    return {false, Sym};
  Sym = make<GdbSymbol>(Hash, Offset);
  return {true, Sym};
}

void GdbHashTab::finalizeContents() {
  uint32_t Size = std::max<uint32_t>(1024, NextPowerOf2(Map.size() * 4 / 3));
  uint32_t Mask = Size - 1;
  Table.resize(Size);

  for (auto &P : Map) {
    GdbSymbol *Sym = P.second;
    uint32_t I = Sym->NameHash & Mask;
    uint32_t Step = ((Sym->NameHash * 17) & Mask) | 1;

    while (Table[I])
      I = (I + Step) & Mask;
    Table[I] = Sym;
  }
}
