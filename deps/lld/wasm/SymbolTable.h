//===- SymbolTable.h --------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_WASM_SYMBOL_TABLE_H
#define LLD_WASM_SYMBOL_TABLE_H

#include "InputFiles.h"
#include "LTO.h"
#include "Symbols.h"
#include "lld/Common/LLVM.h"
#include "llvm/ADT/CachedHashString.h"
#include "llvm/ADT/DenseSet.h"

namespace lld {
namespace wasm {

class InputSegment;

// SymbolTable is a bucket of all known symbols, including defined,
// undefined, or lazy symbols (the last one is symbols in archive
// files whose archive members are not yet loaded).
//
// We put all symbols of all files to a SymbolTable, and the
// SymbolTable selects the "best" symbols if there are name
// conflicts. For example, obviously, a defined symbol is better than
// an undefined symbol. Or, if there's a conflict between a lazy and a
// undefined, it'll read an archive member to read a real definition
// to replace the lazy symbol. The logic is implemented in the
// add*() functions, which are called by input files as they are parsed.
// There is one add* function per symbol type.
class SymbolTable {
public:
  void addFile(InputFile *File);
  void addCombinedLTOObject();

  std::vector<ObjFile *> ObjectFiles;
  std::vector<BitcodeFile *> BitcodeFiles;
  std::vector<InputFunction *> SyntheticFunctions;
  std::vector<InputGlobal *> SyntheticGlobals;

  void reportRemainingUndefines();

  ArrayRef<Symbol *> getSymbols() const { return SymVector; }
  Symbol *find(StringRef Name);

  Symbol *addDefinedFunction(StringRef Name, uint32_t Flags, InputFile *File,
                             InputFunction *Function);
  Symbol *addDefinedData(StringRef Name, uint32_t Flags, InputFile *File,
                         InputSegment *Segment, uint32_t Address,
                         uint32_t Size);
  Symbol *addDefinedGlobal(StringRef Name, uint32_t Flags, InputFile *File,
                           InputGlobal *G);
  Symbol *addDefinedEvent(StringRef Name, uint32_t Flags, InputFile *File,
                          InputEvent *E);

  Symbol *addUndefinedFunction(StringRef Name, StringRef ImportName,
                               StringRef ImportModule, uint32_t Flags,
                               InputFile *File, const WasmSignature *Signature);
  Symbol *addUndefinedData(StringRef Name, uint32_t Flags, InputFile *File);
  Symbol *addUndefinedGlobal(StringRef Name, StringRef ImportName,
                             StringRef ImportModule,  uint32_t Flags,
                             InputFile *File, const WasmGlobalType *Type);

  void addLazy(ArchiveFile *F, const llvm::object::Archive::Symbol *Sym);

  bool addComdat(StringRef Name);

  DefinedData *addSyntheticDataSymbol(StringRef Name, uint32_t Flags);
  DefinedGlobal *addSyntheticGlobal(StringRef Name, uint32_t Flags,
                                    InputGlobal *Global);
  DefinedFunction *addSyntheticFunction(StringRef Name, uint32_t Flags,
                                        InputFunction *Function);

private:
  std::pair<Symbol *, bool> insert(StringRef Name, InputFile *File);

  llvm::DenseMap<llvm::CachedHashStringRef, Symbol *> SymMap;
  std::vector<Symbol *> SymVector;

  llvm::DenseSet<llvm::CachedHashStringRef> Comdats;

  // For LTO.
  std::unique_ptr<BitcodeCompiler> LTO;
};

extern SymbolTable *Symtab;

} // namespace wasm
} // namespace lld

#endif
