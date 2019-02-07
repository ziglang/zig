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
#include "InputChunks.h"
#include "InputEvent.h"
#include "InputGlobal.h"
#include "WriterUtils.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "llvm/ADT/SetVector.h"

#define DEBUG_TYPE "lld"

using namespace llvm;
using namespace llvm::wasm;
using namespace llvm::object;
using namespace lld;
using namespace lld::wasm;

SymbolTable *lld::wasm::Symtab;

void SymbolTable::addFile(InputFile *File) {
  log("Processing: " + toString(File));
  File->parse();

  // LLVM bitcode file
  if (auto *F = dyn_cast<BitcodeFile>(File))
    BitcodeFiles.push_back(F);
  else if (auto *F = dyn_cast<ObjFile>(File))
    ObjectFiles.push_back(F);
}

// This function is where all the optimizations of link-time
// optimization happens. When LTO is in use, some input files are
// not in native object file format but in the LLVM bitcode format.
// This function compiles bitcode files into a few big native files
// using LLVM functions and replaces bitcode symbols with the results.
// Because all bitcode files that the program consists of are passed
// to the compiler at once, it can do whole-program optimization.
void SymbolTable::addCombinedLTOObject() {
  if (BitcodeFiles.empty())
    return;

  // Compile bitcode files and replace bitcode symbols.
  LTO.reset(new BitcodeCompiler);
  for (BitcodeFile *F : BitcodeFiles)
    LTO->add(*F);

  for (StringRef Filename : LTO->compile()) {
    auto *Obj = make<ObjFile>(MemoryBufferRef(Filename, "lto.tmp"));
    Obj->parse();
    ObjectFiles.push_back(Obj);
  }
}

void SymbolTable::reportRemainingUndefines() {
  for (Symbol *Sym : SymVector) {
    if (!Sym->isUndefined() || Sym->isWeak())
      continue;
    if (Config->AllowUndefinedSymbols.count(Sym->getName()) != 0)
      continue;
    if (!Sym->IsUsedInRegularObj)
      continue;
    error(toString(Sym->getFile()) + ": undefined symbol: " + toString(*Sym));
  }
}

Symbol *SymbolTable::find(StringRef Name) {
  return SymMap.lookup(CachedHashStringRef(Name));
}

std::pair<Symbol *, bool> SymbolTable::insert(StringRef Name, InputFile *File) {
  bool Inserted = false;
  Symbol *&Sym = SymMap[CachedHashStringRef(Name)];
  if (!Sym) {
    Sym = reinterpret_cast<Symbol *>(make<SymbolUnion>());
    Sym->IsUsedInRegularObj = false;
    SymVector.emplace_back(Sym);
    Inserted = true;
  }
  if (!File || File->kind() == InputFile::ObjectKind)
    Sym->IsUsedInRegularObj = true;
  return {Sym, Inserted};
}

static void reportTypeError(const Symbol *Existing, const InputFile *File,
                            llvm::wasm::WasmSymbolType Type) {
  error("symbol type mismatch: " + toString(*Existing) + "\n>>> defined as " +
        toString(Existing->getWasmType()) + " in " +
        toString(Existing->getFile()) + "\n>>> defined as " + toString(Type) +
        " in " + toString(File));
}

// Check the type of new symbol matches that of the symbol is replacing.
// For functions this can also involve verifying that the signatures match.
static void checkFunctionType(Symbol *Existing, const InputFile *File,
                              const WasmSignature *NewSig) {
  auto ExistingFunction = dyn_cast<FunctionSymbol>(Existing);
  if (!ExistingFunction) {
    reportTypeError(Existing, File, WASM_SYMBOL_TYPE_FUNCTION);
    return;
  }

  if (!NewSig)
    return;

  const WasmSignature *OldSig = ExistingFunction->Signature;
  if (!OldSig) {
    ExistingFunction->Signature = NewSig;
    return;
  }

  if (*NewSig != *OldSig)
    warn("function signature mismatch: " + Existing->getName() +
         "\n>>> defined as " + toString(*OldSig) + " in " +
         toString(Existing->getFile()) + "\n>>> defined as " +
         toString(*NewSig) + " in " + toString(File));
}

static void checkGlobalType(const Symbol *Existing, const InputFile *File,
                            const WasmGlobalType *NewType) {
  if (!isa<GlobalSymbol>(Existing)) {
    reportTypeError(Existing, File, WASM_SYMBOL_TYPE_GLOBAL);
    return;
  }

  const WasmGlobalType *OldType = cast<GlobalSymbol>(Existing)->getGlobalType();
  if (*NewType != *OldType) {
    error("Global type mismatch: " + Existing->getName() + "\n>>> defined as " +
          toString(*OldType) + " in " + toString(Existing->getFile()) +
          "\n>>> defined as " + toString(*NewType) + " in " + toString(File));
  }
}

static void checkEventType(const Symbol *Existing, const InputFile *File,
                           const WasmEventType *NewType,
                           const WasmSignature *NewSig) {
  auto ExistingEvent = dyn_cast<EventSymbol>(Existing);
  if (!isa<EventSymbol>(Existing)) {
    reportTypeError(Existing, File, WASM_SYMBOL_TYPE_EVENT);
    return;
  }

  const WasmEventType *OldType = cast<EventSymbol>(Existing)->getEventType();
  const WasmSignature *OldSig = ExistingEvent->Signature;
  if (NewType->Attribute != OldType->Attribute)
    error("Event type mismatch: " + Existing->getName() + "\n>>> defined as " +
          toString(*OldType) + " in " + toString(Existing->getFile()) +
          "\n>>> defined as " + toString(*NewType) + " in " + toString(File));
  if (*NewSig != *OldSig)
    warn("Event signature mismatch: " + Existing->getName() +
         "\n>>> defined as " + toString(*OldSig) + " in " +
         toString(Existing->getFile()) + "\n>>> defined as " +
         toString(*NewSig) + " in " + toString(File));
}

static void checkDataType(const Symbol *Existing, const InputFile *File) {
  if (!isa<DataSymbol>(Existing))
    reportTypeError(Existing, File, WASM_SYMBOL_TYPE_DATA);
}

DefinedFunction *SymbolTable::addSyntheticFunction(StringRef Name,
                                                   uint32_t Flags,
                                                   InputFunction *Function) {
  LLVM_DEBUG(dbgs() << "addSyntheticFunction: " << Name << "\n");
  assert(!find(Name));
  SyntheticFunctions.emplace_back(Function);
  return replaceSymbol<DefinedFunction>(insert(Name, nullptr).first, Name,
                                        Flags, nullptr, Function);
}

DefinedData *SymbolTable::addSyntheticDataSymbol(StringRef Name,
                                                 uint32_t Flags) {
  LLVM_DEBUG(dbgs() << "addSyntheticDataSymbol: " << Name << "\n");
  assert(!find(Name));
  return replaceSymbol<DefinedData>(insert(Name, nullptr).first, Name, Flags);
}

DefinedGlobal *SymbolTable::addSyntheticGlobal(StringRef Name, uint32_t Flags,
                                               InputGlobal *Global) {
  LLVM_DEBUG(dbgs() << "addSyntheticGlobal: " << Name << " -> " << Global
                    << "\n");
  assert(!find(Name));
  SyntheticGlobals.emplace_back(Global);
  return replaceSymbol<DefinedGlobal>(insert(Name, nullptr).first, Name, Flags,
                                      nullptr, Global);
}

static bool shouldReplace(const Symbol *Existing, InputFile *NewFile,
                          uint32_t NewFlags) {
  // If existing symbol is undefined, replace it.
  if (!Existing->isDefined()) {
    LLVM_DEBUG(dbgs() << "resolving existing undefined symbol: "
                      << Existing->getName() << "\n");
    return true;
  }

  // Now we have two defined symbols. If the new one is weak, we can ignore it.
  if ((NewFlags & WASM_SYMBOL_BINDING_MASK) == WASM_SYMBOL_BINDING_WEAK) {
    LLVM_DEBUG(dbgs() << "existing symbol takes precedence\n");
    return false;
  }

  // If the existing symbol is weak, we should replace it.
  if (Existing->isWeak()) {
    LLVM_DEBUG(dbgs() << "replacing existing weak symbol\n");
    return true;
  }

  // Neither symbol is week. They conflict.
  error("duplicate symbol: " + toString(*Existing) + "\n>>> defined in " +
        toString(Existing->getFile()) + "\n>>> defined in " +
        toString(NewFile));
  return true;
}

Symbol *SymbolTable::addDefinedFunction(StringRef Name, uint32_t Flags,
                                        InputFile *File,
                                        InputFunction *Function) {
  LLVM_DEBUG(dbgs() << "addDefinedFunction: " << Name << " ["
                    << (Function ? toString(Function->Signature) : "none")
                    << "]\n");
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name, File);

  if (WasInserted || S->isLazy()) {
    replaceSymbol<DefinedFunction>(S, Name, Flags, File, Function);
    return S;
  }

  if (Function)
    checkFunctionType(S, File, &Function->Signature);

  if (shouldReplace(S, File, Flags)) {
    // If the new defined function doesn't have signture (i.e. bitcode
    // functions) but the old symbols does then preserve the old signature
    const WasmSignature *OldSig = nullptr;
    if (auto* F = dyn_cast<FunctionSymbol>(S))
      OldSig = F->Signature;
    auto NewSym = replaceSymbol<DefinedFunction>(S, Name, Flags, File, Function);
    if (!NewSym->Signature)
      NewSym->Signature = OldSig;
  }
  return S;
}

Symbol *SymbolTable::addDefinedData(StringRef Name, uint32_t Flags,
                                    InputFile *File, InputSegment *Segment,
                                    uint32_t Address, uint32_t Size) {
  LLVM_DEBUG(dbgs() << "addDefinedData:" << Name << " addr:" << Address
                    << "\n");
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name, File);

  if (WasInserted || S->isLazy()) {
    replaceSymbol<DefinedData>(S, Name, Flags, File, Segment, Address, Size);
    return S;
  }

  checkDataType(S, File);

  if (shouldReplace(S, File, Flags))
    replaceSymbol<DefinedData>(S, Name, Flags, File, Segment, Address, Size);
  return S;
}

Symbol *SymbolTable::addDefinedGlobal(StringRef Name, uint32_t Flags,
                                      InputFile *File, InputGlobal *Global) {
  LLVM_DEBUG(dbgs() << "addDefinedGlobal:" << Name << "\n");

  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name, File);

  if (WasInserted || S->isLazy()) {
    replaceSymbol<DefinedGlobal>(S, Name, Flags, File, Global);
    return S;
  }

  checkGlobalType(S, File, &Global->getType());

  if (shouldReplace(S, File, Flags))
    replaceSymbol<DefinedGlobal>(S, Name, Flags, File, Global);
  return S;
}

Symbol *SymbolTable::addDefinedEvent(StringRef Name, uint32_t Flags,
                                     InputFile *File, InputEvent *Event) {
  LLVM_DEBUG(dbgs() << "addDefinedEvent:" << Name << "\n");

  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name, File);

  if (WasInserted || S->isLazy()) {
    replaceSymbol<DefinedEvent>(S, Name, Flags, File, Event);
    return S;
  }

  checkEventType(S, File, &Event->getType(), &Event->Signature);

  if (shouldReplace(S, File, Flags))
    replaceSymbol<DefinedEvent>(S, Name, Flags, File, Event);
  return S;
}

Symbol *SymbolTable::addUndefinedFunction(StringRef Name, uint32_t Flags,
                                          InputFile *File,
                                          const WasmSignature *Sig) {
  LLVM_DEBUG(dbgs() << "addUndefinedFunction: " << Name <<
             " [" << (Sig ? toString(*Sig) : "none") << "]\n");

  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name, File);

  if (WasInserted)
    replaceSymbol<UndefinedFunction>(S, Name, Flags, File, Sig);
  else if (auto *Lazy = dyn_cast<LazySymbol>(S))
    Lazy->fetch();
  else
    checkFunctionType(S, File, Sig);

  return S;
}

Symbol *SymbolTable::addUndefinedData(StringRef Name, uint32_t Flags,
                                      InputFile *File) {
  LLVM_DEBUG(dbgs() << "addUndefinedData: " << Name << "\n");

  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name, File);

  if (WasInserted)
    replaceSymbol<UndefinedData>(S, Name, Flags, File);
  else if (auto *Lazy = dyn_cast<LazySymbol>(S))
    Lazy->fetch();
  else if (S->isDefined())
    checkDataType(S, File);
  return S;
}

Symbol *SymbolTable::addUndefinedGlobal(StringRef Name, uint32_t Flags,
                                        InputFile *File,
                                        const WasmGlobalType *Type) {
  LLVM_DEBUG(dbgs() << "addUndefinedGlobal: " << Name << "\n");

  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name, File);

  if (WasInserted)
    replaceSymbol<UndefinedGlobal>(S, Name, Flags, File, Type);
  else if (auto *Lazy = dyn_cast<LazySymbol>(S))
    Lazy->fetch();
  else if (S->isDefined())
    checkGlobalType(S, File, Type);
  return S;
}

void SymbolTable::addLazy(ArchiveFile *File, const Archive::Symbol *Sym) {
  LLVM_DEBUG(dbgs() << "addLazy: " << Sym->getName() << "\n");
  StringRef Name = Sym->getName();

  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name, nullptr);

  if (WasInserted) {
    replaceSymbol<LazySymbol>(S, Name, File, *Sym);
    return;
  }

  // If there is an existing undefined symbol, load a new one from the archive.
  if (S->isUndefined()) {
    LLVM_DEBUG(dbgs() << "replacing existing undefined\n");
    File->addMember(Sym);
  }
}

bool SymbolTable::addComdat(StringRef Name) {
  return Comdats.insert(CachedHashStringRef(Name)).second;
}
