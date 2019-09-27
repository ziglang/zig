//===- SymbolTable.h --------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_ELF_SYMBOL_TABLE_H
#define LLD_ELF_SYMBOL_TABLE_H

#include "InputFiles.h"
#include "Symbols.h"
#include "lld/Common/Strings.h"
#include "llvm/ADT/CachedHashString.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/STLExtras.h"

namespace lld {
namespace elf {

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
// add*() functions, which are called by input files as they are parsed. There
// is one add* function per symbol type.
class SymbolTable {
public:
  void wrap(Symbol *sym, Symbol *real, Symbol *wrap);

  void forEachSymbol(llvm::function_ref<void(Symbol *)> fn) {
    for (Symbol *sym : symVector)
      if (!sym->isPlaceholder())
        fn(sym);
  }

  Symbol *insert(StringRef name);

  Symbol *addSymbol(const Symbol &New);

  void scanVersionScript();

  Symbol *find(StringRef name);

  void handleDynamicList();

  // Set of .so files to not link the same shared object file more than once.
  llvm::DenseMap<StringRef, SharedFile *> soNames;

  // Comdat groups define "link once" sections. If two comdat groups have the
  // same name, only one of them is linked, and the other is ignored. This map
  // is used to uniquify them.
  llvm::DenseMap<llvm::CachedHashStringRef, const InputFile *> comdatGroups;

private:
  std::vector<Symbol *> findByVersion(SymbolVersion ver);
  std::vector<Symbol *> findAllByVersion(SymbolVersion ver);

  llvm::StringMap<std::vector<Symbol *>> &getDemangledSyms();
  void assignExactVersion(SymbolVersion ver, uint16_t versionId,
                          StringRef versionName);
  void assignWildcardVersion(SymbolVersion ver, uint16_t versionId);

  // The order the global symbols are in is not defined. We can use an arbitrary
  // order, but it has to be reproducible. That is true even when cross linking.
  // The default hashing of StringRef produces different results on 32 and 64
  // bit systems so we use a map to a vector. That is arbitrary, deterministic
  // but a bit inefficient.
  // FIXME: Experiment with passing in a custom hashing or sorting the symbols
  // once symbol resolution is finished.
  llvm::DenseMap<llvm::CachedHashStringRef, int> symMap;
  std::vector<Symbol *> symVector;

  // A map from demangled symbol names to their symbol objects.
  // This mapping is 1:N because two symbols with different versions
  // can have the same name. We use this map to handle "extern C++ {}"
  // directive in version scripts.
  llvm::Optional<llvm::StringMap<std::vector<Symbol *>>> demangledSyms;
};

extern SymbolTable *symtab;

} // namespace elf
} // namespace lld

#endif
