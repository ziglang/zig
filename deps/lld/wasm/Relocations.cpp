//===- Relocations.cpp ----------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "Relocations.h"

#include "InputChunks.h"
#include "SyntheticSections.h"

using namespace llvm;
using namespace llvm::wasm;

using namespace lld;
using namespace lld::wasm;

static bool requiresGOTAccess(const Symbol *sym) {
  return config->isPic && !sym->isHidden() && !sym->isLocal();
}

static bool allowUndefined(const Symbol* sym) {
  // Historically --allow-undefined doesn't work for data symbols since we don't
  // have any way to represent these as imports in the final binary.  The idea
  // behind allowing undefined symbols is to allow importing these symbols from
  // the embedder and we can't do this for data symbols (at least not without
  // compiling with -fPIC)
  if (isa<DataSymbol>(sym))
    return false;
  return (config->allowUndefined ||
          config->allowUndefinedSymbols.count(sym->getName()) != 0);
}

static void reportUndefined(const Symbol* sym) {
  assert(sym->isUndefined());
  assert(!sym->isWeak());
  if (!allowUndefined(sym))
    error(toString(sym->getFile()) + ": undefined symbol: " + toString(*sym));
}

void lld::wasm::scanRelocations(InputChunk *chunk) {
  if (!chunk->live)
    return;
  ObjFile *file = chunk->file;
  ArrayRef<WasmSignature> types = file->getWasmObj()->types();
  for (const WasmRelocation &reloc : chunk->getRelocations()) {
    if (reloc.Type == R_WASM_TYPE_INDEX_LEB) {
      // Mark target type as live
      file->typeMap[reloc.Index] =
          out.typeSec->registerType(types[reloc.Index]);
      file->typeIsUsed[reloc.Index] = true;
      continue;
    }

    // Other relocation types all have a corresponding symbol
    Symbol *sym = file->getSymbols()[reloc.Index];

    switch (reloc.Type) {
    case R_WASM_TABLE_INDEX_I32:
    case R_WASM_TABLE_INDEX_SLEB:
    case R_WASM_TABLE_INDEX_REL_SLEB:
      if (requiresGOTAccess(sym))
        break;
      out.elemSec->addEntry(cast<FunctionSymbol>(sym));
      break;
    case R_WASM_GLOBAL_INDEX_LEB:
      if (!isa<GlobalSymbol>(sym))
        out.importSec->addGOTEntry(sym);
      break;
    }

    if (config->isPic) {
      switch (reloc.Type) {
      case R_WASM_TABLE_INDEX_SLEB:
      case R_WASM_MEMORY_ADDR_SLEB:
      case R_WASM_MEMORY_ADDR_LEB:
        // Certain relocation types can't be used when building PIC output,
        // since they would require absolute symbol addresses at link time.
        error(toString(file) + ": relocation " + relocTypeToString(reloc.Type) +
              " cannot be used against symbol " + toString(*sym) +
              "; recompile with -fPIC");
        break;
      case R_WASM_TABLE_INDEX_I32:
      case R_WASM_MEMORY_ADDR_I32:
        // These relocation types are only present in the data section and
        // will be converted into code by `generateRelocationCode`.  This code
        // requires the symbols to have GOT entires.
        if (requiresGOTAccess(sym))
          out.importSec->addGOTEntry(sym);
        break;
      }
    } else {
      // Report undefined symbols
      if (sym->isUndefined() && !config->relocatable && !sym->isWeak())
        reportUndefined(sym);
    }

  }
}
