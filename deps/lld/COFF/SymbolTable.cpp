//===- SymbolTable.cpp ----------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "SymbolTable.h"
#include "Config.h"
#include "Driver.h"
#include "LTO.h"
#include "PDB.h"
#include "Symbols.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "lld/Common/Timer.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/Object/WindowsMachineFlag.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"
#include <utility>

using namespace llvm;

namespace lld {
namespace coff {

static Timer ltoTimer("LTO", Timer::root());

SymbolTable *symtab;

void SymbolTable::addFile(InputFile *file) {
  log("Reading " + toString(file));
  file->parse();

  MachineTypes mt = file->getMachineType();
  if (config->machine == IMAGE_FILE_MACHINE_UNKNOWN) {
    config->machine = mt;
  } else if (mt != IMAGE_FILE_MACHINE_UNKNOWN && config->machine != mt) {
    error(toString(file) + ": machine type " + machineToStr(mt) +
          " conflicts with " + machineToStr(config->machine));
    return;
  }

  if (auto *f = dyn_cast<ObjFile>(file)) {
    ObjFile::instances.push_back(f);
  } else if (auto *f = dyn_cast<BitcodeFile>(file)) {
    BitcodeFile::instances.push_back(f);
  } else if (auto *f = dyn_cast<ImportFile>(file)) {
    ImportFile::instances.push_back(f);
  }

  driver->parseDirectives(file);
}

static void errorOrWarn(const Twine &s) {
  if (config->forceUnresolved)
    warn(s);
  else
    error(s);
}

// Returns the symbol in SC whose value is <= Addr that is closest to Addr.
// This is generally the global variable or function whose definition contains
// Addr.
static Symbol *getSymbol(SectionChunk *sc, uint32_t addr) {
  DefinedRegular *candidate = nullptr;

  for (Symbol *s : sc->file->getSymbols()) {
    auto *d = dyn_cast_or_null<DefinedRegular>(s);
    if (!d || !d->data || d->getChunk() != sc || d->getValue() > addr ||
        (candidate && d->getValue() < candidate->getValue()))
      continue;

    candidate = d;
  }

  return candidate;
}

// Given a file and the index of a symbol in that file, returns a description
// of all references to that symbol from that file. If no debug information is
// available, returns just the name of the file, else one string per actual
// reference as described in the debug info.
std::vector<std::string> getSymbolLocations(ObjFile *file, uint32_t symIndex) {
  struct Location {
    Symbol *sym;
    std::pair<StringRef, uint32_t> fileLine;
  };
  std::vector<Location> locations;

  for (Chunk *c : file->getChunks()) {
    auto *sc = dyn_cast<SectionChunk>(c);
    if (!sc)
      continue;
    for (const coff_relocation &r : sc->getRelocs()) {
      if (r.SymbolTableIndex != symIndex)
        continue;
      std::pair<StringRef, uint32_t> fileLine =
          getFileLine(sc, r.VirtualAddress);
      Symbol *sym = getSymbol(sc, r.VirtualAddress);
      if (!fileLine.first.empty() || sym)
        locations.push_back({sym, fileLine});
    }
  }

  if (locations.empty())
    return std::vector<std::string>({"\n>>> referenced by " + toString(file)});

  std::vector<std::string> symbolLocations(locations.size());
  size_t i = 0;
  for (Location loc : locations) {
    llvm::raw_string_ostream os(symbolLocations[i++]);
    os << "\n>>> referenced by ";
    if (!loc.fileLine.first.empty())
      os << loc.fileLine.first << ":" << loc.fileLine.second
         << "\n>>>               ";
    os << toString(file);
    if (loc.sym)
      os << ":(" << toString(*loc.sym) << ')';
  }
  return symbolLocations;
}

// For an undefined symbol, stores all files referencing it and the index of
// the undefined symbol in each file.
struct UndefinedDiag {
  Symbol *sym;
  struct File {
    ObjFile *oFile;
    uint64_t symIndex;
  };
  std::vector<File> files;
};

static void reportUndefinedSymbol(const UndefinedDiag &undefDiag) {
  std::string out;
  llvm::raw_string_ostream os(out);
  os << "undefined symbol: " << toString(*undefDiag.sym);

  const size_t maxUndefReferences = 10;
  size_t i = 0, numRefs = 0;
  for (const UndefinedDiag::File &ref : undefDiag.files) {
    std::vector<std::string> symbolLocations =
        getSymbolLocations(ref.oFile, ref.symIndex);
    numRefs += symbolLocations.size();
    for (const std::string &s : symbolLocations) {
      if (i >= maxUndefReferences)
        break;
      os << s;
      i++;
    }
  }
  if (i < numRefs)
    os << "\n>>> referenced " << numRefs - i << " more times";
  errorOrWarn(os.str());
}

void SymbolTable::loadMinGWAutomaticImports() {
  for (auto &i : symMap) {
    Symbol *sym = i.second;
    auto *undef = dyn_cast<Undefined>(sym);
    if (!undef)
      continue;
    if (!sym->isUsedInRegularObj)
      continue;

    StringRef name = undef->getName();

    if (name.startswith("__imp_"))
      continue;
    // If we have an undefined symbol, but we have a Lazy representing a
    // symbol we could load from file, make sure to load that.
    Lazy *l = dyn_cast_or_null<Lazy>(find(("__imp_" + name).str()));
    if (!l || l->pendingArchiveLoad)
      continue;

    log("Loading lazy " + l->getName() + " from " + l->file->getName() +
        " for automatic import");
    l->pendingArchiveLoad = true;
    l->file->addMember(l->sym);
  }
}

bool SymbolTable::handleMinGWAutomaticImport(Symbol *sym, StringRef name) {
  if (name.startswith("__imp_"))
    return false;
  Defined *imp = dyn_cast_or_null<Defined>(find(("__imp_" + name).str()));
  if (!imp)
    return false;

  // Replace the reference directly to a variable with a reference
  // to the import address table instead. This obviously isn't right,
  // but we mark the symbol as isRuntimePseudoReloc, and a later pass
  // will add runtime pseudo relocations for every relocation against
  // this Symbol. The runtime pseudo relocation framework expects the
  // reference itself to point at the IAT entry.
  size_t impSize = 0;
  if (isa<DefinedImportData>(imp)) {
    log("Automatically importing " + name + " from " +
        cast<DefinedImportData>(imp)->getDLLName());
    impSize = sizeof(DefinedImportData);
  } else if (isa<DefinedRegular>(imp)) {
    log("Automatically importing " + name + " from " +
        toString(cast<DefinedRegular>(imp)->file));
    impSize = sizeof(DefinedRegular);
  } else {
    warn("unable to automatically import " + name + " from " + imp->getName() +
         " from " + toString(cast<DefinedRegular>(imp)->file) +
         "; unexpected symbol type");
    return false;
  }
  sym->replaceKeepingName(imp, impSize);
  sym->isRuntimePseudoReloc = true;

  // There may exist symbols named .refptr.<name> which only consist
  // of a single pointer to <name>. If it turns out <name> is
  // automatically imported, we don't need to keep the .refptr.<name>
  // pointer at all, but redirect all accesses to it to the IAT entry
  // for __imp_<name> instead, and drop the whole .refptr.<name> chunk.
  DefinedRegular *refptr =
      dyn_cast_or_null<DefinedRegular>(find((".refptr." + name).str()));
  if (refptr && refptr->getChunk()->getSize() == config->wordsize) {
    SectionChunk *sc = dyn_cast_or_null<SectionChunk>(refptr->getChunk());
    if (sc && sc->getRelocs().size() == 1 && *sc->symbols().begin() == sym) {
      log("Replacing .refptr." + name + " with " + imp->getName());
      refptr->getChunk()->live = false;
      refptr->replaceKeepingName(imp, impSize);
    }
  }
  return true;
}

void SymbolTable::reportRemainingUndefines() {
  SmallPtrSet<Symbol *, 8> undefs;
  DenseMap<Symbol *, Symbol *> localImports;

  for (auto &i : symMap) {
    Symbol *sym = i.second;
    auto *undef = dyn_cast<Undefined>(sym);
    if (!undef)
      continue;
    if (!sym->isUsedInRegularObj)
      continue;

    StringRef name = undef->getName();

    // A weak alias may have been resolved, so check for that.
    if (Defined *d = undef->getWeakAlias()) {
      // We want to replace Sym with D. However, we can't just blindly
      // copy sizeof(SymbolUnion) bytes from D to Sym because D may be an
      // internal symbol, and internal symbols are stored as "unparented"
      // Symbols. For that reason we need to check which type of symbol we
      // are dealing with and copy the correct number of bytes.
      if (isa<DefinedRegular>(d))
        memcpy(sym, d, sizeof(DefinedRegular));
      else if (isa<DefinedAbsolute>(d))
        memcpy(sym, d, sizeof(DefinedAbsolute));
      else
        memcpy(sym, d, sizeof(SymbolUnion));
      continue;
    }

    // If we can resolve a symbol by removing __imp_ prefix, do that.
    // This odd rule is for compatibility with MSVC linker.
    if (name.startswith("__imp_")) {
      Symbol *imp = find(name.substr(strlen("__imp_")));
      if (imp && isa<Defined>(imp)) {
        auto *d = cast<Defined>(imp);
        replaceSymbol<DefinedLocalImport>(sym, name, d);
        localImportChunks.push_back(cast<DefinedLocalImport>(sym)->getChunk());
        localImports[sym] = d;
        continue;
      }
    }

    // We don't want to report missing Microsoft precompiled headers symbols.
    // A proper message will be emitted instead in PDBLinker::aquirePrecompObj
    if (name.contains("_PchSym_"))
      continue;

    if (config->mingw && handleMinGWAutomaticImport(sym, name))
      continue;

    // Remaining undefined symbols are not fatal if /force is specified.
    // They are replaced with dummy defined symbols.
    if (config->forceUnresolved)
      replaceSymbol<DefinedAbsolute>(sym, name, 0);
    undefs.insert(sym);
  }

  if (undefs.empty() && localImports.empty())
    return;

  for (Symbol *b : config->gcroot) {
    if (undefs.count(b))
      errorOrWarn("<root>: undefined symbol: " + toString(*b));
    if (config->warnLocallyDefinedImported)
      if (Symbol *imp = localImports.lookup(b))
        warn("<root>: locally defined symbol imported: " + toString(*imp) +
             " (defined in " + toString(imp->getFile()) + ") [LNK4217]");
  }

  std::vector<UndefinedDiag> undefDiags;
  DenseMap<Symbol *, int> firstDiag;

  for (ObjFile *file : ObjFile::instances) {
    size_t symIndex = (size_t)-1;
    for (Symbol *sym : file->getSymbols()) {
      ++symIndex;
      if (!sym)
        continue;
      if (undefs.count(sym)) {
        auto it = firstDiag.find(sym);
        if (it == firstDiag.end()) {
          firstDiag[sym] = undefDiags.size();
          undefDiags.push_back({sym, {{file, symIndex}}});
        } else {
          undefDiags[it->second].files.push_back({file, symIndex});
        }
      }
      if (config->warnLocallyDefinedImported)
        if (Symbol *imp = localImports.lookup(sym))
          warn(toString(file) +
               ": locally defined symbol imported: " + toString(*imp) +
               " (defined in " + toString(imp->getFile()) + ") [LNK4217]");
    }
  }

  for (const UndefinedDiag& undefDiag : undefDiags)
    reportUndefinedSymbol(undefDiag);
}

std::pair<Symbol *, bool> SymbolTable::insert(StringRef name) {
  bool inserted = false;
  Symbol *&sym = symMap[CachedHashStringRef(name)];
  if (!sym) {
    sym = reinterpret_cast<Symbol *>(make<SymbolUnion>());
    sym->isUsedInRegularObj = false;
    sym->pendingArchiveLoad = false;
    inserted = true;
  }
  return {sym, inserted};
}

std::pair<Symbol *, bool> SymbolTable::insert(StringRef name, InputFile *file) {
  std::pair<Symbol *, bool> result = insert(name);
  if (!file || !isa<BitcodeFile>(file))
    result.first->isUsedInRegularObj = true;
  return result;
}

Symbol *SymbolTable::addUndefined(StringRef name, InputFile *f,
                                  bool isWeakAlias) {
  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insert(name, f);
  if (wasInserted || (isa<Lazy>(s) && isWeakAlias)) {
    replaceSymbol<Undefined>(s, name);
    return s;
  }
  if (auto *l = dyn_cast<Lazy>(s)) {
    if (!s->pendingArchiveLoad) {
      s->pendingArchiveLoad = true;
      l->file->addMember(l->sym);
    }
  }
  return s;
}

void SymbolTable::addLazy(ArchiveFile *f, const Archive::Symbol &sym) {
  StringRef name = sym.getName();
  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insert(name);
  if (wasInserted) {
    replaceSymbol<Lazy>(s, f, sym);
    return;
  }
  auto *u = dyn_cast<Undefined>(s);
  if (!u || u->weakAlias || s->pendingArchiveLoad)
    return;
  s->pendingArchiveLoad = true;
  f->addMember(sym);
}

void SymbolTable::reportDuplicate(Symbol *existing, InputFile *newFile) {
  std::string msg = "duplicate symbol: " + toString(*existing) + " in " +
                    toString(existing->getFile()) + " and in " +
                    toString(newFile);

  if (config->forceMultiple)
    warn(msg);
  else
    error(msg);
}

Symbol *SymbolTable::addAbsolute(StringRef n, COFFSymbolRef sym) {
  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insert(n, nullptr);
  s->isUsedInRegularObj = true;
  if (wasInserted || isa<Undefined>(s) || isa<Lazy>(s))
    replaceSymbol<DefinedAbsolute>(s, n, sym);
  else if (!isa<DefinedCOFF>(s))
    reportDuplicate(s, nullptr);
  return s;
}

Symbol *SymbolTable::addAbsolute(StringRef n, uint64_t va) {
  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insert(n, nullptr);
  s->isUsedInRegularObj = true;
  if (wasInserted || isa<Undefined>(s) || isa<Lazy>(s))
    replaceSymbol<DefinedAbsolute>(s, n, va);
  else if (!isa<DefinedCOFF>(s))
    reportDuplicate(s, nullptr);
  return s;
}

Symbol *SymbolTable::addSynthetic(StringRef n, Chunk *c) {
  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insert(n, nullptr);
  s->isUsedInRegularObj = true;
  if (wasInserted || isa<Undefined>(s) || isa<Lazy>(s))
    replaceSymbol<DefinedSynthetic>(s, n, c);
  else if (!isa<DefinedCOFF>(s))
    reportDuplicate(s, nullptr);
  return s;
}

Symbol *SymbolTable::addRegular(InputFile *f, StringRef n,
                                const coff_symbol_generic *sym,
                                SectionChunk *c) {
  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insert(n, f);
  if (wasInserted || !isa<DefinedRegular>(s))
    replaceSymbol<DefinedRegular>(s, f, n, /*IsCOMDAT*/ false,
                                  /*IsExternal*/ true, sym, c);
  else
    reportDuplicate(s, f);
  return s;
}

std::pair<DefinedRegular *, bool>
SymbolTable::addComdat(InputFile *f, StringRef n,
                       const coff_symbol_generic *sym) {
  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insert(n, f);
  if (wasInserted || !isa<DefinedRegular>(s)) {
    replaceSymbol<DefinedRegular>(s, f, n, /*IsCOMDAT*/ true,
                                  /*IsExternal*/ true, sym, nullptr);
    return {cast<DefinedRegular>(s), true};
  }
  auto *existingSymbol = cast<DefinedRegular>(s);
  if (!existingSymbol->isCOMDAT)
    reportDuplicate(s, f);
  return {existingSymbol, false};
}

Symbol *SymbolTable::addCommon(InputFile *f, StringRef n, uint64_t size,
                               const coff_symbol_generic *sym, CommonChunk *c) {
  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insert(n, f);
  if (wasInserted || !isa<DefinedCOFF>(s))
    replaceSymbol<DefinedCommon>(s, f, n, size, sym, c);
  else if (auto *dc = dyn_cast<DefinedCommon>(s))
    if (size > dc->getSize())
      replaceSymbol<DefinedCommon>(s, f, n, size, sym, c);
  return s;
}

Symbol *SymbolTable::addImportData(StringRef n, ImportFile *f) {
  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insert(n, nullptr);
  s->isUsedInRegularObj = true;
  if (wasInserted || isa<Undefined>(s) || isa<Lazy>(s)) {
    replaceSymbol<DefinedImportData>(s, n, f);
    return s;
  }

  reportDuplicate(s, f);
  return nullptr;
}

Symbol *SymbolTable::addImportThunk(StringRef name, DefinedImportData *id,
                                    uint16_t machine) {
  Symbol *s;
  bool wasInserted;
  std::tie(s, wasInserted) = insert(name, nullptr);
  s->isUsedInRegularObj = true;
  if (wasInserted || isa<Undefined>(s) || isa<Lazy>(s)) {
    replaceSymbol<DefinedImportThunk>(s, name, id, machine);
    return s;
  }

  reportDuplicate(s, id->file);
  return nullptr;
}

void SymbolTable::addLibcall(StringRef name) {
  Symbol *sym = findUnderscore(name);
  if (!sym)
    return;

  if (Lazy *l = dyn_cast<Lazy>(sym)) {
    MemoryBufferRef mb = l->getMemberBuffer();
    if (identify_magic(mb.getBuffer()) == llvm::file_magic::bitcode)
      addUndefined(sym->getName());
  }
}

std::vector<Chunk *> SymbolTable::getChunks() {
  std::vector<Chunk *> res;
  for (ObjFile *file : ObjFile::instances) {
    ArrayRef<Chunk *> v = file->getChunks();
    res.insert(res.end(), v.begin(), v.end());
  }
  return res;
}

Symbol *SymbolTable::find(StringRef name) {
  return symMap.lookup(CachedHashStringRef(name));
}

Symbol *SymbolTable::findUnderscore(StringRef name) {
  if (config->machine == I386)
    return find(("_" + name).str());
  return find(name);
}

// Return all symbols that start with Prefix, possibly ignoring the first
// character of Prefix or the first character symbol.
std::vector<Symbol *> SymbolTable::getSymsWithPrefix(StringRef prefix) {
  std::vector<Symbol *> syms;
  for (auto pair : symMap) {
    StringRef name = pair.first.val();
    if (name.startswith(prefix) || name.startswith(prefix.drop_front()) ||
        name.drop_front().startswith(prefix) ||
        name.drop_front().startswith(prefix.drop_front())) {
      syms.push_back(pair.second);
    }
  }
  return syms;
}

Symbol *SymbolTable::findMangle(StringRef name) {
  if (Symbol *sym = find(name))
    if (!isa<Undefined>(sym))
      return sym;

  // Efficient fuzzy string lookup is impossible with a hash table, so iterate
  // the symbol table once and collect all possibly matching symbols into this
  // vector. Then compare each possibly matching symbol with each possible
  // mangling.
  std::vector<Symbol *> syms = getSymsWithPrefix(name);
  auto findByPrefix = [&syms](const Twine &t) -> Symbol * {
    std::string prefix = t.str();
    for (auto *s : syms)
      if (s->getName().startswith(prefix))
        return s;
    return nullptr;
  };

  // For non-x86, just look for C++ functions.
  if (config->machine != I386)
    return findByPrefix("?" + name + "@@Y");

  if (!name.startswith("_"))
    return nullptr;
  // Search for x86 stdcall function.
  if (Symbol *s = findByPrefix(name + "@"))
    return s;
  // Search for x86 fastcall function.
  if (Symbol *s = findByPrefix("@" + name.substr(1) + "@"))
    return s;
  // Search for x86 vectorcall function.
  if (Symbol *s = findByPrefix(name.substr(1) + "@@"))
    return s;
  // Search for x86 C++ non-member function.
  return findByPrefix("?" + name.substr(1) + "@@Y");
}

Symbol *SymbolTable::addUndefined(StringRef name) {
  return addUndefined(name, nullptr, false);
}

std::vector<StringRef> SymbolTable::compileBitcodeFiles() {
  lto.reset(new BitcodeCompiler);
  for (BitcodeFile *f : BitcodeFile::instances)
    lto->add(*f);
  return lto->compile();
}

void SymbolTable::addCombinedLTOObjects() {
  if (BitcodeFile::instances.empty())
    return;

  ScopedTimer t(ltoTimer);
  for (StringRef object : compileBitcodeFiles()) {
    auto *obj = make<ObjFile>(MemoryBufferRef(object, "lto.tmp"));
    obj->parse();
    ObjFile::instances.push_back(obj);
  }
}

} // namespace coff
} // namespace lld
