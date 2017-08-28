//===- GdbIndex.h --------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===-------------------------------------------------------------------===//

#ifndef LLD_ELF_GDB_INDEX_H
#define LLD_ELF_GDB_INDEX_H

#include "InputFiles.h"
#include "llvm/DebugInfo/DWARF/DWARFContext.h"
#include "llvm/Object/ELF.h"

namespace lld {
namespace elf {

class InputSection;

// Struct represents single entry of address area of gdb index.
struct AddressEntry {
  InputSection *Section;
  uint64_t LowAddress;
  uint64_t HighAddress;
  uint32_t CuIndex;
};

// Struct represents single entry of compilation units list area of gdb index.
// It consist of CU offset in .debug_info section and it's size.
struct CompilationUnitEntry {
  uint64_t CuOffset;
  uint64_t CuLength;
};

// Represents data about symbol and type names which are used
// to build symbol table and constant pool area of gdb index.
struct NameTypeEntry {
  StringRef Name;
  uint8_t Type;
};

// We fill one GdbIndexDataChunk for each object where scan of
// debug information performed. That information futher used
// for filling gdb index section areas.
struct GdbIndexChunk {
  InputSection *DebugInfoSec;
  std::vector<AddressEntry> AddressArea;
  std::vector<CompilationUnitEntry> CompilationUnits;
  std::vector<NameTypeEntry> NamesAndTypes;
};

// Element of GdbHashTab hash table.
struct GdbSymbol {
  GdbSymbol(uint32_t Hash, size_t Offset)
      : NameHash(Hash), NameOffset(Offset) {}
  uint32_t NameHash;
  size_t NameOffset;
  size_t CuVectorIndex;
};

// This class manages the hashed symbol table for the .gdb_index section.
// The hash value for a table entry is computed by applying an iterative hash
// function to the symbol's name.
class GdbHashTab final {
public:
  std::pair<bool, GdbSymbol *> add(uint32_t Hash, size_t Offset);

  void finalizeContents();
  size_t getCapacity() { return Table.size(); }
  GdbSymbol *getSymbol(size_t I) { return Table[I]; }

private:
  llvm::DenseMap<size_t, GdbSymbol *> Map;
  std::vector<GdbSymbol *> Table;
};

} // namespace elf
} // namespace lld

#endif
