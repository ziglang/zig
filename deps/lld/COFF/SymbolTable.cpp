//===- SymbolTable.cpp ----------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "SymbolTable.h"
#include "Config.h"
#include "Driver.h"
#include "Error.h"
#include "LTO.h"
#include "Memory.h"
#include "Symbols.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"
#include <utility>

using namespace llvm;

namespace lld {
namespace coff {

enum SymbolPreference {
  SP_EXISTING = -1,
  SP_CONFLICT = 0,
  SP_NEW = 1,
};

/// Checks if an existing symbol S should be kept or replaced by a new symbol.
/// Returns SP_EXISTING when S should be kept, SP_NEW when the new symbol
/// should be kept, and SP_CONFLICT if no valid resolution exists.
static SymbolPreference compareDefined(Symbol *S, bool WasInserted,
                                       bool NewIsCOMDAT) {
  // If the symbol wasn't previously known, the new symbol wins by default.
  if (WasInserted || !isa<Defined>(S->body()))
    return SP_NEW;

  // If the existing symbol is a DefinedRegular, both it and the new symbol
  // must be comdats. In that case, we have no reason to prefer one symbol
  // over the other, and we keep the existing one. If one of the symbols
  // is not a comdat, we report a conflict.
  if (auto *R = dyn_cast<DefinedRegular>(S->body())) {
    if (NewIsCOMDAT && R->isCOMDAT())
      return SP_EXISTING;
    else
      return SP_CONFLICT;
  }

  // Existing symbol is not a DefinedRegular; new symbol wins.
  return SP_NEW;
}

SymbolTable *Symtab;

void SymbolTable::addFile(InputFile *File) {
  log("Reading " + toString(File));
  File->parse();

  MachineTypes MT = File->getMachineType();
  if (Config->Machine == IMAGE_FILE_MACHINE_UNKNOWN) {
    Config->Machine = MT;
  } else if (MT != IMAGE_FILE_MACHINE_UNKNOWN && Config->Machine != MT) {
    fatal(toString(File) + ": machine type " + machineToStr(MT) +
          " conflicts with " + machineToStr(Config->Machine));
  }

  if (auto *F = dyn_cast<ObjectFile>(File)) {
    ObjectFiles.push_back(F);
  } else if (auto *F = dyn_cast<BitcodeFile>(File)) {
    BitcodeFiles.push_back(F);
  } else if (auto *F = dyn_cast<ImportFile>(File)) {
    ImportFiles.push_back(F);
  }

  StringRef S = File->getDirectives();
  if (S.empty())
    return;

  log("Directives: " + toString(File) + ": " + S);
  Driver->parseDirectives(S);
}

void SymbolTable::reportRemainingUndefines() {
  SmallPtrSet<SymbolBody *, 8> Undefs;
  for (auto &I : Symtab) {
    Symbol *Sym = I.second;
    auto *Undef = dyn_cast<Undefined>(Sym->body());
    if (!Undef)
      continue;
    if (!Sym->IsUsedInRegularObj)
      continue;
    StringRef Name = Undef->getName();
    // A weak alias may have been resolved, so check for that.
    if (Defined *D = Undef->getWeakAlias()) {
      // We resolve weak aliases by replacing the alias's SymbolBody with the
      // target's SymbolBody. This causes all SymbolBody pointers referring to
      // the old symbol to instead refer to the new symbol. However, we can't
      // just blindly copy sizeof(Symbol::Body) bytes from D to Sym->Body
      // because D may be an internal symbol, and internal symbols are stored as
      // "unparented" SymbolBodies. For that reason we need to check which type
      // of symbol we are dealing with and copy the correct number of bytes.
      if (isa<DefinedRegular>(D))
        memcpy(Sym->Body.buffer, D, sizeof(DefinedRegular));
      else if (isa<DefinedAbsolute>(D))
        memcpy(Sym->Body.buffer, D, sizeof(DefinedAbsolute));
      else
        // No other internal symbols are possible.
        Sym->Body = D->symbol()->Body;
      continue;
    }
    // If we can resolve a symbol by removing __imp_ prefix, do that.
    // This odd rule is for compatibility with MSVC linker.
    if (Name.startswith("__imp_")) {
      Symbol *Imp = find(Name.substr(strlen("__imp_")));
      if (Imp && isa<Defined>(Imp->body())) {
        auto *D = cast<Defined>(Imp->body());
        replaceBody<DefinedLocalImport>(Sym, Name, D);
        LocalImportChunks.push_back(
            cast<DefinedLocalImport>(Sym->body())->getChunk());
        continue;
      }
    }
    // Remaining undefined symbols are not fatal if /force is specified.
    // They are replaced with dummy defined symbols.
    if (Config->Force)
      replaceBody<DefinedAbsolute>(Sym, Name, 0);
    Undefs.insert(Sym->body());
  }
  if (Undefs.empty())
    return;
  for (SymbolBody *B : Config->GCRoot)
    if (Undefs.count(B))
      warn("<root>: undefined symbol: " + B->getName());
  for (ObjectFile *File : ObjectFiles)
    for (SymbolBody *Sym : File->getSymbols())
      if (Undefs.count(Sym))
        warn(toString(File) + ": undefined symbol: " + Sym->getName());
  if (!Config->Force)
    fatal("link failed");
}

std::pair<Symbol *, bool> SymbolTable::insert(StringRef Name) {
  Symbol *&Sym = Symtab[CachedHashStringRef(Name)];
  if (Sym)
    return {Sym, false};
  Sym = make<Symbol>();
  Sym->IsUsedInRegularObj = false;
  Sym->PendingArchiveLoad = false;
  return {Sym, true};
}

Symbol *SymbolTable::addUndefined(StringRef Name, InputFile *F,
                                  bool IsWeakAlias) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name);
  if (!F || !isa<BitcodeFile>(F))
    S->IsUsedInRegularObj = true;
  if (WasInserted || (isa<Lazy>(S->body()) && IsWeakAlias)) {
    replaceBody<Undefined>(S, Name);
    return S;
  }
  if (auto *L = dyn_cast<Lazy>(S->body())) {
    if (!S->PendingArchiveLoad) {
      S->PendingArchiveLoad = true;
      L->File->addMember(&L->Sym);
    }
  }
  return S;
}

void SymbolTable::addLazy(ArchiveFile *F, const Archive::Symbol Sym) {
  StringRef Name = Sym.getName();
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name);
  if (WasInserted) {
    replaceBody<Lazy>(S, F, Sym);
    return;
  }
  auto *U = dyn_cast<Undefined>(S->body());
  if (!U || U->WeakAlias || S->PendingArchiveLoad)
    return;
  S->PendingArchiveLoad = true;
  F->addMember(&Sym);
}

void SymbolTable::reportDuplicate(Symbol *Existing, InputFile *NewFile) {
  error("duplicate symbol: " + toString(*Existing->body()) + " in " +
        toString(Existing->body()->getFile()) + " and in " +
        (NewFile ? toString(NewFile) : "(internal)"));
}

Symbol *SymbolTable::addAbsolute(StringRef N, COFFSymbolRef Sym) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(N);
  S->IsUsedInRegularObj = true;
  if (WasInserted || isa<Undefined>(S->body()) || isa<Lazy>(S->body()))
    replaceBody<DefinedAbsolute>(S, N, Sym);
  else if (!isa<DefinedCOFF>(S->body()))
    reportDuplicate(S, nullptr);
  return S;
}

Symbol *SymbolTable::addAbsolute(StringRef N, uint64_t VA) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(N);
  S->IsUsedInRegularObj = true;
  if (WasInserted || isa<Undefined>(S->body()) || isa<Lazy>(S->body()))
    replaceBody<DefinedAbsolute>(S, N, VA);
  else if (!isa<DefinedCOFF>(S->body()))
    reportDuplicate(S, nullptr);
  return S;
}

Symbol *SymbolTable::addSynthetic(StringRef N, Chunk *C) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(N);
  S->IsUsedInRegularObj = true;
  if (WasInserted || isa<Undefined>(S->body()) || isa<Lazy>(S->body()))
    replaceBody<DefinedSynthetic>(S, N, C);
  else if (!isa<DefinedCOFF>(S->body()))
    reportDuplicate(S, nullptr);
  return S;
}

Symbol *SymbolTable::addRegular(InputFile *F, StringRef N, bool IsCOMDAT,
                                const coff_symbol_generic *Sym,
                                SectionChunk *C) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(N);
  if (!isa<BitcodeFile>(F))
    S->IsUsedInRegularObj = true;
  SymbolPreference SP = compareDefined(S, WasInserted, IsCOMDAT);
  if (SP == SP_CONFLICT) {
    reportDuplicate(S, F);
  } else if (SP == SP_NEW) {
    replaceBody<DefinedRegular>(S, F, N, IsCOMDAT, /*IsExternal*/ true, Sym, C);
  } else if (SP == SP_EXISTING && IsCOMDAT && C) {
    C->markDiscarded();
    // Discard associative chunks that we've parsed so far. No need to recurse
    // because an associative section cannot have children.
    for (SectionChunk *Child : C->children())
      Child->markDiscarded();
  }
  return S;
}

Symbol *SymbolTable::addCommon(InputFile *F, StringRef N, uint64_t Size,
                               const coff_symbol_generic *Sym, CommonChunk *C) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(N);
  if (!isa<BitcodeFile>(F))
    S->IsUsedInRegularObj = true;
  if (WasInserted || !isa<DefinedCOFF>(S->body()))
    replaceBody<DefinedCommon>(S, F, N, Size, Sym, C);
  else if (auto *DC = dyn_cast<DefinedCommon>(S->body()))
    if (Size > DC->getSize())
      replaceBody<DefinedCommon>(S, F, N, Size, Sym, C);
  return S;
}

Symbol *SymbolTable::addImportData(StringRef N, ImportFile *F) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(N);
  S->IsUsedInRegularObj = true;
  if (WasInserted || isa<Undefined>(S->body()) || isa<Lazy>(S->body()))
    replaceBody<DefinedImportData>(S, N, F);
  else if (!isa<DefinedCOFF>(S->body()))
    reportDuplicate(S, nullptr);
  return S;
}

Symbol *SymbolTable::addImportThunk(StringRef Name, DefinedImportData *ID,
                                    uint16_t Machine) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name);
  S->IsUsedInRegularObj = true;
  if (WasInserted || isa<Undefined>(S->body()) || isa<Lazy>(S->body()))
    replaceBody<DefinedImportThunk>(S, Name, ID, Machine);
  else if (!isa<DefinedCOFF>(S->body()))
    reportDuplicate(S, nullptr);
  return S;
}

std::vector<Chunk *> SymbolTable::getChunks() {
  std::vector<Chunk *> Res;
  for (ObjectFile *File : ObjectFiles) {
    std::vector<Chunk *> &V = File->getChunks();
    Res.insert(Res.end(), V.begin(), V.end());
  }
  return Res;
}

Symbol *SymbolTable::find(StringRef Name) {
  auto It = Symtab.find(CachedHashStringRef(Name));
  if (It == Symtab.end())
    return nullptr;
  return It->second;
}

Symbol *SymbolTable::findUnderscore(StringRef Name) {
  if (Config->Machine == I386)
    return find(("_" + Name).str());
  return find(Name);
}

StringRef SymbolTable::findByPrefix(StringRef Prefix) {
  for (auto Pair : Symtab) {
    StringRef Name = Pair.first.val();
    if (Name.startswith(Prefix))
      return Name;
  }
  return "";
}

StringRef SymbolTable::findMangle(StringRef Name) {
  if (Symbol *Sym = find(Name))
    if (!isa<Undefined>(Sym->body()))
      return Name;
  if (Config->Machine != I386)
    return findByPrefix(("?" + Name + "@@Y").str());
  if (!Name.startswith("_"))
    return "";
  // Search for x86 C function.
  StringRef S = findByPrefix((Name + "@").str());
  if (!S.empty())
    return S;
  // Search for x86 C++ non-member function.
  return findByPrefix(("?" + Name.substr(1) + "@@Y").str());
}

void SymbolTable::mangleMaybe(SymbolBody *B) {
  auto *U = dyn_cast<Undefined>(B);
  if (!U || U->WeakAlias)
    return;
  StringRef Alias = findMangle(U->getName());
  if (!Alias.empty())
    U->WeakAlias = addUndefined(Alias);
}

SymbolBody *SymbolTable::addUndefined(StringRef Name) {
  return addUndefined(Name, nullptr, false)->body();
}

std::vector<StringRef> SymbolTable::compileBitcodeFiles() {
  LTO.reset(new BitcodeCompiler);
  for (BitcodeFile *F : BitcodeFiles)
    LTO->add(*F);
  return LTO->compile();
}

void SymbolTable::addCombinedLTOObjects() {
  if (BitcodeFiles.empty())
    return;
  for (StringRef Object : compileBitcodeFiles()) {
    auto *Obj = make<ObjectFile>(MemoryBufferRef(Object, "lto.tmp"));
    Obj->parse();
    ObjectFiles.push_back(Obj);
  }
}

} // namespace coff
} // namespace lld
