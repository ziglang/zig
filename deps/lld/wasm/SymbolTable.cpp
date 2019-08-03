//===- SymbolTable.cpp ----------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
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

SymbolTable *lld::wasm::symtab;

void SymbolTable::addFile(InputFile *file) {
  log("Processing: " + toString(file));

  // .a file
  if (auto *f = dyn_cast<ArchiveFile>(file)) {
    f->parse();
    return;
  }

  // .so file
  if (auto *f = dyn_cast<SharedFile>(file)) {
    sharedFiles.push_back(f);
    return;
  }

  if (config->trace)
    message(toString(file));

  // LLVM bitcode file
  if (auto *f = dyn_cast<BitcodeFile>(file)) {
    f->parse();
    bitcodeFiles.push_back(f);
    return;
  }

  // Regular object file
  auto *f = cast<ObjFile>(file);
  f->parse(false);
  objectFiles.push_back(f);
}

// This function is where all the optimizations of link-time
// optimization happens. When LTO is in use, some input files are
// not in native object file format but in the LLVM bitcode format.
// This function compiles bitcode files into a few big native files
// using LLVM functions and replaces bitcode symbols with the results.
// Because all bitcode files that the program consists of are passed
// to the compiler at once, it can do whole-program optimization.
void SymbolTable::addCombinedLTOObject() {
  if (bitcodeFiles.empty())
    return;

  // Compile bitcode files and replace bitcode symbols.
  lto.reset(new BitcodeCompiler);
  for (BitcodeFile *f : bitcodeFiles)
    lto->add(*f);

  for (StringRef filename : lto->compile()) {
    auto *obj = make<ObjFile>(MemoryBufferRef(filename, "lto.tmp"), "");
    obj->parse(true);
    objectFiles.push_back(obj);
  }
}

Symbol *SymbolTable::find(StringRef name) {
  auto it = symMap.find(CachedHashStringRef(name));
  if (it == symMap.end() || it->second == -1)
    return nullptr;
  return symVector[it->second];
}

void SymbolTable::replace(StringRef name, Symbol* sym) {
  auto it = symMap.find(CachedHashStringRef(name));
  symVector[it->second] = sym;
}

std::pair<Symbol *, bool> SymbolTable::insertName(StringRef name) {
  bool trace = false;
  auto p = symMap.insert({CachedHashStringRef(name), (int)symVector.size()});
  int &symIndex = p.first->second;
  bool isNew = p.second;
  if (symIndex == -1) {
    symIndex = symVector.size();
    trace = true;
    isNew = true;
  }

  if (!isNew)
    return {symVector[symIndex], false};

  Symbol *sym = reinterpret_cast<Symbol *>(make<SymbolUnion>());
  sym->isUsedInRegularObj = false;
  sym->canInline = true;
  sym->traced = trace;
  symVector.emplace_back(sym);
  return {sym, true};
}

std::pair<Symbol *, bool> SymbolTable::insert(StringRef name,
                                              const InputFile *file) {
  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insertName(name);

  if (!file || file->kind() == InputFile::ObjectKind)
    s->isUsedInRegularObj = true;

  return {s, wasInserted};
}

static void reportTypeError(const Symbol *existing, const InputFile *file,
                            llvm::wasm::WasmSymbolType type) {
  error("symbol type mismatch: " + toString(*existing) + "\n>>> defined as " +
        toString(existing->getWasmType()) + " in " +
        toString(existing->getFile()) + "\n>>> defined as " + toString(type) +
        " in " + toString(file));
}

// Check the type of new symbol matches that of the symbol is replacing.
// Returns true if the function types match, false is there is a singature
// mismatch.
static bool signatureMatches(FunctionSymbol *existing,
                             const WasmSignature *newSig) {
  const WasmSignature *oldSig = existing->signature;

  // If either function is missing a signature (this happend for bitcode
  // symbols) then assume they match.  Any mismatch will be reported later
  // when the LTO objects are added.
  if (!newSig || !oldSig)
    return true;

  return *newSig == *oldSig;
}

static void checkGlobalType(const Symbol *existing, const InputFile *file,
                            const WasmGlobalType *newType) {
  if (!isa<GlobalSymbol>(existing)) {
    reportTypeError(existing, file, WASM_SYMBOL_TYPE_GLOBAL);
    return;
  }

  const WasmGlobalType *oldType = cast<GlobalSymbol>(existing)->getGlobalType();
  if (*newType != *oldType) {
    error("Global type mismatch: " + existing->getName() + "\n>>> defined as " +
          toString(*oldType) + " in " + toString(existing->getFile()) +
          "\n>>> defined as " + toString(*newType) + " in " + toString(file));
  }
}

static void checkEventType(const Symbol *existing, const InputFile *file,
                           const WasmEventType *newType,
                           const WasmSignature *newSig) {
  auto existingEvent = dyn_cast<EventSymbol>(existing);
  if (!isa<EventSymbol>(existing)) {
    reportTypeError(existing, file, WASM_SYMBOL_TYPE_EVENT);
    return;
  }

  const WasmEventType *oldType = cast<EventSymbol>(existing)->getEventType();
  const WasmSignature *oldSig = existingEvent->signature;
  if (newType->Attribute != oldType->Attribute)
    error("Event type mismatch: " + existing->getName() + "\n>>> defined as " +
          toString(*oldType) + " in " + toString(existing->getFile()) +
          "\n>>> defined as " + toString(*newType) + " in " + toString(file));
  if (*newSig != *oldSig)
    warn("Event signature mismatch: " + existing->getName() +
         "\n>>> defined as " + toString(*oldSig) + " in " +
         toString(existing->getFile()) + "\n>>> defined as " +
         toString(*newSig) + " in " + toString(file));
}

static void checkDataType(const Symbol *existing, const InputFile *file) {
  if (!isa<DataSymbol>(existing))
    reportTypeError(existing, file, WASM_SYMBOL_TYPE_DATA);
}

DefinedFunction *SymbolTable::addSyntheticFunction(StringRef name,
                                                   uint32_t flags,
                                                   InputFunction *function) {
  LLVM_DEBUG(dbgs() << "addSyntheticFunction: " << name << "\n");
  assert(!find(name));
  syntheticFunctions.emplace_back(function);
  return replaceSymbol<DefinedFunction>(insertName(name).first, name,
                                        flags, nullptr, function);
}

// Adds an optional, linker generated, data symbols.  The symbol will only be
// added if there is an undefine reference to it, or if it is explictly exported
// via the --export flag.  Otherwise we don't add the symbol and return nullptr.
DefinedData *SymbolTable::addOptionalDataSymbol(StringRef name, uint32_t value,
                                                uint32_t flags) {
  Symbol *s = find(name);
  if (!s && (config->exportAll || config->exportedSymbols.count(name) != 0))
    s = insertName(name).first;
  else if (!s || s->isDefined())
    return nullptr;
  LLVM_DEBUG(dbgs() << "addOptionalDataSymbol: " << name << "\n");
  auto *rtn = replaceSymbol<DefinedData>(s, name, flags);
  rtn->setVirtualAddress(value);
  rtn->referenced = true;
  return rtn;
}

DefinedData *SymbolTable::addSyntheticDataSymbol(StringRef name,
                                                 uint32_t flags) {
  LLVM_DEBUG(dbgs() << "addSyntheticDataSymbol: " << name << "\n");
  assert(!find(name));
  return replaceSymbol<DefinedData>(insertName(name).first, name, flags);
}

DefinedGlobal *SymbolTable::addSyntheticGlobal(StringRef name, uint32_t flags,
                                               InputGlobal *global) {
  LLVM_DEBUG(dbgs() << "addSyntheticGlobal: " << name << " -> " << global
                    << "\n");
  assert(!find(name));
  syntheticGlobals.emplace_back(global);
  return replaceSymbol<DefinedGlobal>(insertName(name).first, name, flags,
                                      nullptr, global);
}

static bool shouldReplace(const Symbol *existing, InputFile *newFile,
                          uint32_t newFlags) {
  // If existing symbol is undefined, replace it.
  if (!existing->isDefined()) {
    LLVM_DEBUG(dbgs() << "resolving existing undefined symbol: "
                      << existing->getName() << "\n");
    return true;
  }

  // Now we have two defined symbols. If the new one is weak, we can ignore it.
  if ((newFlags & WASM_SYMBOL_BINDING_MASK) == WASM_SYMBOL_BINDING_WEAK) {
    LLVM_DEBUG(dbgs() << "existing symbol takes precedence\n");
    return false;
  }

  // If the existing symbol is weak, we should replace it.
  if (existing->isWeak()) {
    LLVM_DEBUG(dbgs() << "replacing existing weak symbol\n");
    return true;
  }

  // Neither symbol is week. They conflict.
  error("duplicate symbol: " + toString(*existing) + "\n>>> defined in " +
        toString(existing->getFile()) + "\n>>> defined in " +
        toString(newFile));
  return true;
}

Symbol *SymbolTable::addDefinedFunction(StringRef name, uint32_t flags,
                                        InputFile *file,
                                        InputFunction *function) {
  LLVM_DEBUG(dbgs() << "addDefinedFunction: " << name << " ["
                    << (function ? toString(function->signature) : "none")
                    << "]\n");
  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insert(name, file);

  auto replaceSym = [&](Symbol *sym) {
    // If the new defined function doesn't have signture (i.e. bitcode
    // functions) but the old symbol does, then preserve the old signature
    const WasmSignature *oldSig = s->getSignature();
    auto* newSym = replaceSymbol<DefinedFunction>(sym, name, flags, file, function);
    if (!newSym->signature)
      newSym->signature = oldSig;
  };

  if (wasInserted || s->isLazy()) {
    replaceSym(s);
    return s;
  }

  auto existingFunction = dyn_cast<FunctionSymbol>(s);
  if (!existingFunction) {
    reportTypeError(s, file, WASM_SYMBOL_TYPE_FUNCTION);
    return s;
  }

  bool checkSig = true;
  if (auto ud = dyn_cast<UndefinedFunction>(existingFunction))
    checkSig = ud->isCalledDirectly;

  if (checkSig && function && !signatureMatches(existingFunction, &function->signature)) {
    Symbol* variant;
    if (getFunctionVariant(s, &function->signature, file, &variant))
      // New variant, always replace
      replaceSym(variant);
    else if (shouldReplace(s, file, flags))
      // Variant already exists, replace it after checking shouldReplace
      replaceSym(variant);

    // This variant we found take the place in the symbol table as the primary
    // variant.
    replace(name, variant);
    return variant;
  }

  // Existing function with matching signature.
  if (shouldReplace(s, file, flags))
    replaceSym(s);

  return s;
}

Symbol *SymbolTable::addDefinedData(StringRef name, uint32_t flags,
                                    InputFile *file, InputSegment *segment,
                                    uint32_t address, uint32_t size) {
  LLVM_DEBUG(dbgs() << "addDefinedData:" << name << " addr:" << address
                    << "\n");
  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insert(name, file);

  auto replaceSym = [&]() {
    replaceSymbol<DefinedData>(s, name, flags, file, segment, address, size);
  };

  if (wasInserted || s->isLazy()) {
    replaceSym();
    return s;
  }

  checkDataType(s, file);

  if (shouldReplace(s, file, flags))
    replaceSym();
  return s;
}

Symbol *SymbolTable::addDefinedGlobal(StringRef name, uint32_t flags,
                                      InputFile *file, InputGlobal *global) {
  LLVM_DEBUG(dbgs() << "addDefinedGlobal:" << name << "\n");

  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insert(name, file);

  auto replaceSym = [&]() {
    replaceSymbol<DefinedGlobal>(s, name, flags, file, global);
  };

  if (wasInserted || s->isLazy()) {
    replaceSym();
    return s;
  }

  checkGlobalType(s, file, &global->getType());

  if (shouldReplace(s, file, flags))
    replaceSym();
  return s;
}

Symbol *SymbolTable::addDefinedEvent(StringRef name, uint32_t flags,
                                     InputFile *file, InputEvent *event) {
  LLVM_DEBUG(dbgs() << "addDefinedEvent:" << name << "\n");

  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insert(name, file);

  auto replaceSym = [&]() {
    replaceSymbol<DefinedEvent>(s, name, flags, file, event);
  };

  if (wasInserted || s->isLazy()) {
    replaceSym();
    return s;
  }

  checkEventType(s, file, &event->getType(), &event->signature);

  if (shouldReplace(s, file, flags))
    replaceSym();
  return s;
}

Symbol *SymbolTable::addUndefinedFunction(StringRef name, StringRef importName,
                                          StringRef importModule,
                                          uint32_t flags, InputFile *file,
                                          const WasmSignature *sig,
                                          bool isCalledDirectly) {
  LLVM_DEBUG(dbgs() << "addUndefinedFunction: " << name << " ["
                    << (sig ? toString(*sig) : "none")
                    << "] IsCalledDirectly:" << isCalledDirectly << "\n");

  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insert(name, file);
  if (s->traced)
    printTraceSymbolUndefined(name, file);

  auto replaceSym = [&]() {
    replaceSymbol<UndefinedFunction>(s, name, importName, importModule, flags,
                                     file, sig, isCalledDirectly);
  };

  if (wasInserted)
    replaceSym();
  else if (auto *lazy = dyn_cast<LazySymbol>(s))
    lazy->fetch();
  else {
    auto existingFunction = dyn_cast<FunctionSymbol>(s);
    if (!existingFunction) {
      reportTypeError(s, file, WASM_SYMBOL_TYPE_FUNCTION);
      return s;
    }
    if (!existingFunction->signature && sig)
      existingFunction->signature = sig;
    if (isCalledDirectly && !signatureMatches(existingFunction, sig))
      if (getFunctionVariant(s, sig, file, &s))
        replaceSym();
  }

  return s;
}

Symbol *SymbolTable::addUndefinedData(StringRef name, uint32_t flags,
                                      InputFile *file) {
  LLVM_DEBUG(dbgs() << "addUndefinedData: " << name << "\n");

  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insert(name, file);
  if (s->traced)
    printTraceSymbolUndefined(name, file);

  if (wasInserted)
    replaceSymbol<UndefinedData>(s, name, flags, file);
  else if (auto *lazy = dyn_cast<LazySymbol>(s))
    lazy->fetch();
  else if (s->isDefined())
    checkDataType(s, file);
  return s;
}

Symbol *SymbolTable::addUndefinedGlobal(StringRef name, StringRef importName,
                                        StringRef importModule, uint32_t flags,
                                        InputFile *file,
                                        const WasmGlobalType *type) {
  LLVM_DEBUG(dbgs() << "addUndefinedGlobal: " << name << "\n");

  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insert(name, file);
  if (s->traced)
    printTraceSymbolUndefined(name, file);

  if (wasInserted)
    replaceSymbol<UndefinedGlobal>(s, name, importName, importModule, flags,
                                   file, type);
  else if (auto *lazy = dyn_cast<LazySymbol>(s))
    lazy->fetch();
  else if (s->isDefined())
    checkGlobalType(s, file, type);
  return s;
}

void SymbolTable::addLazy(ArchiveFile *file, const Archive::Symbol *sym) {
  LLVM_DEBUG(dbgs() << "addLazy: " << sym->getName() << "\n");
  StringRef name = sym->getName();

  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insertName(name);

  if (wasInserted) {
    replaceSymbol<LazySymbol>(s, name, 0, file, *sym);
    return;
  }

  if (!s->isUndefined())
    return;

  // The existing symbol is undefined, load a new one from the archive,
  // unless the the existing symbol is weak in which case replace the undefined
  // symbols with a LazySymbol.
  if (s->isWeak()) {
    const WasmSignature *oldSig = nullptr;
    // In the case of an UndefinedFunction we need to preserve the expected
    // signature.
    if (auto *f = dyn_cast<UndefinedFunction>(s))
      oldSig = f->signature;
    LLVM_DEBUG(dbgs() << "replacing existing weak undefined symbol\n");
    auto newSym = replaceSymbol<LazySymbol>(s, name, WASM_SYMBOL_BINDING_WEAK,
                                            file, *sym);
    newSym->signature = oldSig;
    return;
  }

  LLVM_DEBUG(dbgs() << "replacing existing undefined\n");
  file->addMember(sym);
}

bool SymbolTable::addComdat(StringRef name) {
  return comdatGroups.insert(CachedHashStringRef(name)).second;
}

// The new signature doesn't match.  Create a variant to the symbol with the
// signature encoded in the name and return that instead.  These symbols are
// then unified later in handleSymbolVariants.
bool SymbolTable::getFunctionVariant(Symbol* sym, const WasmSignature *sig,
                                     const InputFile *file, Symbol **out) {
  LLVM_DEBUG(dbgs() << "getFunctionVariant: " << sym->getName() << " -> "
                    << " " << toString(*sig) << "\n");
  Symbol *variant = nullptr;

  // Linear search through symbol variants.  Should never be more than two
  // or three entries here.
  auto &variants = symVariants[CachedHashStringRef(sym->getName())];
  if (variants.empty())
    variants.push_back(sym);

  for (Symbol* v : variants) {
    if (*v->getSignature() == *sig) {
      variant = v;
      break;
    }
  }

  bool wasAdded = !variant;
  if (wasAdded) {
    // Create a new variant;
    LLVM_DEBUG(dbgs() << "added new variant\n");
    variant = reinterpret_cast<Symbol *>(make<SymbolUnion>());
    variants.push_back(variant);
  } else {
    LLVM_DEBUG(dbgs() << "variant already exists: " << toString(*variant) << "\n");
    assert(*variant->getSignature() == *sig);
  }

  *out = variant;
  return wasAdded;
}

// Set a flag for --trace-symbol so that we can print out a log message
// if a new symbol with the same name is inserted into the symbol table.
void SymbolTable::trace(StringRef name) {
  symMap.insert({CachedHashStringRef(name), -1});
}

void SymbolTable::wrap(Symbol *sym, Symbol *real, Symbol *wrap) {
  // Swap symbols as instructed by -wrap.
  int &origIdx = symMap[CachedHashStringRef(sym->getName())];
  int &realIdx= symMap[CachedHashStringRef(real->getName())];
  int &wrapIdx = symMap[CachedHashStringRef(wrap->getName())];
  LLVM_DEBUG(dbgs() << "wrap: " << sym->getName() << "\n");

  // Anyone looking up __real symbols should get the original
  realIdx = origIdx;
  // Anyone looking up the original should get the __wrap symbol
  origIdx = wrapIdx;
}

static const uint8_t unreachableFn[] = {
    0x03 /* ULEB length */, 0x00 /* ULEB num locals */,
    0x00 /* opcode unreachable */, 0x0b /* opcode end */
};

// Replace the given symbol body with an unreachable function.
// This is used by handleWeakUndefines in order to generate a callable
// equivalent of an undefined function and also handleSymbolVariants for
// undefined functions that don't match the signature of the definition.
InputFunction *SymbolTable::replaceWithUnreachable(Symbol *sym,
                                                   const WasmSignature &sig,
                                                   StringRef debugName) {
  auto *func = make<SyntheticFunction>(sig, sym->getName(), debugName);
  func->setBody(unreachableFn);
  syntheticFunctions.emplace_back(func);
  replaceSymbol<DefinedFunction>(sym, sym->getName(), sym->getFlags(), nullptr,
                                 func);
  return func;
}

// For weak undefined functions, there may be "call" instructions that reference
// the symbol. In this case, we need to synthesise a dummy/stub function that
// will abort at runtime, so that relocations can still provided an operand to
// the call instruction that passes Wasm validation.
void SymbolTable::handleWeakUndefines() {
  for (Symbol *sym : getSymbols()) {
    if (!sym->isUndefWeak())
      continue;

    const WasmSignature *sig = sym->getSignature();
    if (!sig) {
      // It is possible for undefined functions not to have a signature (eg. if
      // added via "--undefined"), but weak undefined ones do have a signature.
      // Lazy symbols may not be functions and therefore Sig can still be null
      // in some circumstantce.
      assert(!isa<FunctionSymbol>(sym));
      continue;
    }

    // Add a synthetic dummy for weak undefined functions.  These dummies will
    // be GC'd if not used as the target of any "call" instructions.
    StringRef debugName = saver.save("undefined:" + toString(*sym));
    InputFunction* func = replaceWithUnreachable(sym, *sig, debugName);
    // Ensure it compares equal to the null pointer, and so that table relocs
    // don't pull in the stub body (only call-operand relocs should do that).
    func->setTableIndex(0);
    // Hide our dummy to prevent export.
    sym->setHidden(true);
  }
}

static void reportFunctionSignatureMismatch(StringRef symName,
                                            FunctionSymbol *a,
                                            FunctionSymbol *b, bool isError) {
  std::string msg = ("function signature mismatch: " + symName +
                     "\n>>> defined as " + toString(*a->signature) + " in " +
                     toString(a->getFile()) + "\n>>> defined as " +
                     toString(*b->signature) + " in " + toString(b->getFile()))
                        .str();
  if (isError)
    error(msg);
  else
    warn(msg);
}

// Remove any variant symbols that were created due to function signature
// mismatches.
void SymbolTable::handleSymbolVariants() {
  for (auto pair : symVariants) {
    // Push the initial symbol onto the list of variants.
    StringRef symName = pair.first.val();
    std::vector<Symbol *> &variants = pair.second;

#ifndef NDEBUG
    LLVM_DEBUG(dbgs() << "symbol with (" << variants.size()
                      << ") variants: " << symName << "\n");
    for (auto *s: variants) {
      auto *f = cast<FunctionSymbol>(s);
      LLVM_DEBUG(dbgs() << " variant: " + f->getName() << " "
                        << toString(*f->signature) << "\n");
    }
#endif

    // Find the one definition.
    DefinedFunction *defined = nullptr;
    for (auto *symbol : variants) {
      if (auto f = dyn_cast<DefinedFunction>(symbol)) {
        defined = f;
        break;
      }
    }

    // If there are no definitions, and the undefined symbols disagree on
    // the signature, there is not we can do since we don't know which one
    // to use as the signature on the import.
    if (!defined) {
      reportFunctionSignatureMismatch(symName,
                                      cast<FunctionSymbol>(variants[0]),
                                      cast<FunctionSymbol>(variants[1]), true);
      return;
    }

    for (auto *symbol : variants) {
      if (symbol != defined) {
        auto *f = cast<FunctionSymbol>(symbol);
        reportFunctionSignatureMismatch(symName, f, defined, false);
        StringRef debugName = saver.save("unreachable:" + toString(*f));
        replaceWithUnreachable(f, *f->signature, debugName);
      }
    }
  }
}
