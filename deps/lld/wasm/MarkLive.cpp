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
// chunks from the output. Unused chunks are those that are not reachable from
// known root symbols or chunks. This feature is implemented as a mark-sweep
// garbage collector.
//
// Here's how it works. Each InputChunk has a "Live" bit. The bit is off by
// default. Starting with the GC-roots, visit all reachable chunks and set their
// Live bits. The Writer will then ignore chunks whose Live bits are off, so
// that such chunk are not appear in the output.
//
//===----------------------------------------------------------------------===//

#include "MarkLive.h"
#include "Config.h"
#include "InputChunks.h"
#include "InputGlobal.h"
#include "SymbolTable.h"
#include "Symbols.h"

#define DEBUG_TYPE "lld"

using namespace llvm;
using namespace llvm::wasm;
using namespace lld;
using namespace lld::wasm;

void lld::wasm::markLive() {
  if (!Config->GcSections)
    return;

  LLVM_DEBUG(dbgs() << "markLive\n");
  SmallVector<InputChunk *, 256> Q;

  auto Enqueue = [&](Symbol *Sym) {
    if (!Sym || Sym->isLive())
      return;
    LLVM_DEBUG(dbgs() << "markLive: " << Sym->getName() << "\n");
    Sym->markLive();
    if (InputChunk *Chunk = Sym->getChunk())
      Q.push_back(Chunk);
  };

  // Add GC root symbols.
  if (!Config->Entry.empty())
    Enqueue(Symtab->find(Config->Entry));
  Enqueue(WasmSym::CallCtors);

  // We need to preserve any exported symbol
  for (Symbol *Sym : Symtab->getSymbols())
    if (Sym->isExported())
      Enqueue(Sym);

  // The ctor functions are all used in the synthetic __wasm_call_ctors
  // function, but since this function is created in-place it doesn't contain
  // relocations which mean we have to manually mark the ctors.
  for (const ObjFile *Obj : Symtab->ObjectFiles) {
    const WasmLinkingData &L = Obj->getWasmObj()->linkingData();
    for (const WasmInitFunc &F : L.InitFunctions)
      Enqueue(Obj->getFunctionSymbol(F.Symbol));
  }

  // Follow relocations to mark all reachable chunks.
  while (!Q.empty()) {
    InputChunk *C = Q.pop_back_val();

    for (const WasmRelocation Reloc : C->getRelocations()) {
      if (Reloc.Type == R_WEBASSEMBLY_TYPE_INDEX_LEB)
        continue;
      Symbol *Sym = C->File->getSymbol(Reloc.Index);

      // If the function has been assigned the special index zero in the table,
      // the relocation doesn't pull in the function body, since the function
      // won't actually go in the table (the runtime will trap attempts to call
      // that index, since we don't use it).  A function with a table index of
      // zero is only reachable via "call", not via "call_indirect".  The stub
      // functions used for weak-undefined symbols have this behaviour (compare
      // equal to null pointer, only reachable via direct call).
      if (Reloc.Type == R_WEBASSEMBLY_TABLE_INDEX_SLEB ||
          Reloc.Type == R_WEBASSEMBLY_TABLE_INDEX_I32) {
        FunctionSymbol *FuncSym = cast<FunctionSymbol>(Sym);
        if (FuncSym->hasTableIndex() && FuncSym->getTableIndex() == 0)
          continue;
      }

      Enqueue(Sym);
    }
  }

  // Report garbage-collected sections.
  if (Config->PrintGcSections) {
    for (const ObjFile *Obj : Symtab->ObjectFiles) {
      for (InputChunk *C : Obj->Functions)
        if (!C->Live)
          message("removing unused section " + toString(C));
      for (InputChunk *C : Obj->Segments)
        if (!C->Live)
          message("removing unused section " + toString(C));
      for (InputGlobal *G : Obj->Globals)
        if (!G->Live)
          message("removing unused section " + toString(G));
    }
    for (InputChunk *C : Symtab->SyntheticFunctions)
      if (!C->Live)
        message("removing unused section " + toString(C));
    for (InputGlobal *G : Symtab->SyntheticGlobals)
      if (!G->Live)
        message("removing unused section " + toString(G));
  }
}
