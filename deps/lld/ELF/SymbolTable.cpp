//===- SymbolTable.cpp ----------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// Symbol table is a bag of all known symbols. We put all symbols of
// all input files to the symbol table. The symbol table is basically
// a hash table with the logic to resolve symbol name conflicts using
// the symbol types.
//
//===----------------------------------------------------------------------===//

#include "SymbolTable.h"
#include "Config.h"
#include "LinkerScript.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "lld/Common/Strings.h"
#include "llvm/ADT/STLExtras.h"

using namespace llvm;
using namespace llvm::object;
using namespace llvm::ELF;

using namespace lld;
using namespace lld::elf;

SymbolTable *elf::Symtab;

static InputFile *getFirstElf() {
  if (!ObjectFiles.empty())
    return ObjectFiles[0];
  if (!SharedFiles.empty())
    return SharedFiles[0];
  return nullptr;
}

// All input object files must be for the same architecture
// (e.g. it does not make sense to link x86 object files with
// MIPS object files.) This function checks for that error.
static bool isCompatible(InputFile *F) {
  if (!F->isElf() && !isa<BitcodeFile>(F))
    return true;

  if (F->EKind == Config->EKind && F->EMachine == Config->EMachine) {
    if (Config->EMachine != EM_MIPS)
      return true;
    if (isMipsN32Abi(F) == Config->MipsN32Abi)
      return true;
  }

  if (!Config->Emulation.empty())
    error(toString(F) + " is incompatible with " + Config->Emulation);
  else
    error(toString(F) + " is incompatible with " + toString(getFirstElf()));
  return false;
}

// Add symbols in File to the symbol table.
template <class ELFT> void SymbolTable::addFile(InputFile *File) {
  if (!isCompatible(File))
    return;

  // Binary file
  if (auto *F = dyn_cast<BinaryFile>(File)) {
    BinaryFiles.push_back(F);
    F->parse();
    return;
  }

  // .a file
  if (auto *F = dyn_cast<ArchiveFile>(File)) {
    F->parse<ELFT>();
    return;
  }

  // Lazy object file
  if (auto *F = dyn_cast<LazyObjFile>(File)) {
    F->parse<ELFT>();
    return;
  }

  if (Config->Trace)
    message(toString(File));

  // .so file
  if (auto *F = dyn_cast<SharedFile<ELFT>>(File)) {
    // DSOs are uniquified not by filename but by soname.
    F->parseSoName();
    if (errorCount() || !SoNames.insert(F->SoName).second)
      return;
    SharedFiles.push_back(F);
    F->parseRest();
    return;
  }

  // LLVM bitcode file
  if (auto *F = dyn_cast<BitcodeFile>(File)) {
    BitcodeFiles.push_back(F);
    F->parse<ELFT>(ComdatGroups);
    return;
  }

  // Regular object file
  ObjectFiles.push_back(File);
  cast<ObjFile<ELFT>>(File)->parse(ComdatGroups);
}

// This function is where all the optimizations of link-time
// optimization happens. When LTO is in use, some input files are
// not in native object file format but in the LLVM bitcode format.
// This function compiles bitcode files into a few big native files
// using LLVM functions and replaces bitcode symbols with the results.
// Because all bitcode files that consist of a program are passed
// to the compiler at once, it can do whole-program optimization.
template <class ELFT> void SymbolTable::addCombinedLTOObject() {
  if (BitcodeFiles.empty())
    return;

  // Compile bitcode files and replace bitcode symbols.
  LTO.reset(new BitcodeCompiler);
  for (BitcodeFile *F : BitcodeFiles)
    LTO->add(*F);

  for (InputFile *File : LTO->compile()) {
    DenseSet<CachedHashStringRef> DummyGroups;
    cast<ObjFile<ELFT>>(File)->parse(DummyGroups);
    ObjectFiles.push_back(File);
  }
}

Defined *SymbolTable::addAbsolute(StringRef Name, uint8_t Visibility,
                                  uint8_t Binding) {
  Symbol *Sym =
      addRegular(Name, Visibility, STT_NOTYPE, 0, 0, Binding, nullptr, nullptr);
  return cast<Defined>(Sym);
}

// Set a flag for --trace-symbol so that we can print out a log message
// if a new symbol with the same name is inserted into the symbol table.
void SymbolTable::trace(StringRef Name) {
  SymMap.insert({CachedHashStringRef(Name), -1});
}

// Rename SYM as __wrap_SYM. The original symbol is preserved as __real_SYM.
// Used to implement --wrap.
template <class ELFT> void SymbolTable::addSymbolWrap(StringRef Name) {
  Symbol *Sym = find(Name);
  if (!Sym)
    return;
  Symbol *Real = addUndefined<ELFT>(Saver.save("__real_" + Name));
  Symbol *Wrap = addUndefined<ELFT>(Saver.save("__wrap_" + Name));
  WrappedSymbols.push_back({Sym, Real, Wrap});

  // We want to tell LTO not to inline symbols to be overwritten
  // because LTO doesn't know the final symbol contents after renaming.
  Real->CanInline = false;
  Sym->CanInline = false;

  // Tell LTO not to eliminate these symbols.
  Sym->IsUsedInRegularObj = true;
  Wrap->IsUsedInRegularObj = true;
}

// Apply symbol renames created by -wrap. The renames are created
// before LTO in addSymbolWrap() to have a chance to inform LTO (if
// LTO is running) not to include these symbols in IPO. Now that the
// symbols are finalized, we can perform the replacement.
void SymbolTable::applySymbolWrap() {
  // This function rotates 3 symbols:
  //
  // __real_sym becomes sym
  // sym        becomes __wrap_sym
  // __wrap_sym becomes __real_sym
  //
  // The last part is special in that we don't want to change what references to
  // __wrap_sym point to, we just want have __real_sym in the symbol table.

  for (WrappedSymbol &W : WrappedSymbols) {
    // First, make a copy of __real_sym.
    Symbol *Real = nullptr;
    if (W.Real->isDefined()) {
      Real = (Symbol *)make<SymbolUnion>();
      memcpy(Real, W.Real, sizeof(SymbolUnion));
    }

    // Replace __real_sym with sym and sym with __wrap_sym.
    memcpy(W.Real, W.Sym, sizeof(SymbolUnion));
    memcpy(W.Sym, W.Wrap, sizeof(SymbolUnion));

    // We now have two copies of __wrap_sym. Drop one.
    W.Wrap->IsUsedInRegularObj = false;

    if (Real)
      SymVector.push_back(Real);
  }
}

static uint8_t getMinVisibility(uint8_t VA, uint8_t VB) {
  if (VA == STV_DEFAULT)
    return VB;
  if (VB == STV_DEFAULT)
    return VA;
  return std::min(VA, VB);
}

// Find an existing symbol or create and insert a new one.
std::pair<Symbol *, bool> SymbolTable::insert(StringRef Name) {
  // <name>@@<version> means the symbol is the default version. In that
  // case <name>@@<version> will be used to resolve references to <name>.
  //
  // Since this is a hot path, the following string search code is
  // optimized for speed. StringRef::find(char) is much faster than
  // StringRef::find(StringRef).
  size_t Pos = Name.find('@');
  if (Pos != StringRef::npos && Pos + 1 < Name.size() && Name[Pos + 1] == '@')
    Name = Name.take_front(Pos);

  auto P = SymMap.insert({CachedHashStringRef(Name), (int)SymVector.size()});
  int &SymIndex = P.first->second;
  bool IsNew = P.second;
  bool Traced = false;

  if (SymIndex == -1) {
    SymIndex = SymVector.size();
    IsNew = Traced = true;
  }

  Symbol *Sym;
  if (IsNew) {
    Sym = (Symbol *)make<SymbolUnion>();
    Sym->InVersionScript = false;
    Sym->Visibility = STV_DEFAULT;
    Sym->IsUsedInRegularObj = false;
    Sym->ExportDynamic = false;
    Sym->CanInline = true;
    Sym->Traced = Traced;
    Sym->VersionId = Config->DefaultSymbolVersion;
    SymVector.push_back(Sym);
  } else {
    Sym = SymVector[SymIndex];
  }
  return {Sym, IsNew};
}

// Find an existing symbol or create and insert a new one, then apply the given
// attributes.
std::pair<Symbol *, bool> SymbolTable::insert(StringRef Name, uint8_t Type,
                                              uint8_t Visibility,
                                              bool CanOmitFromDynSym,
                                              InputFile *File) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name);

  // Merge in the new symbol's visibility.
  S->Visibility = getMinVisibility(S->Visibility, Visibility);

  if (!CanOmitFromDynSym && (Config->Shared || Config->ExportDynamic))
    S->ExportDynamic = true;

  if (!File || File->kind() == InputFile::ObjKind)
    S->IsUsedInRegularObj = true;

  if (!WasInserted && S->Type != Symbol::UnknownType &&
      ((Type == STT_TLS) != S->isTls())) {
    error("TLS attribute mismatch: " + toString(*S) + "\n>>> defined in " +
          toString(S->File) + "\n>>> defined in " + toString(File));
  }

  return {S, WasInserted};
}

template <class ELFT> Symbol *SymbolTable::addUndefined(StringRef Name) {
  return addUndefined<ELFT>(Name, STB_GLOBAL, STV_DEFAULT,
                            /*Type*/ 0,
                            /*CanOmitFromDynSym*/ false, /*File*/ nullptr);
}

static uint8_t getVisibility(uint8_t StOther) { return StOther & 3; }

template <class ELFT>
Symbol *SymbolTable::addUndefined(StringRef Name, uint8_t Binding,
                                  uint8_t StOther, uint8_t Type,
                                  bool CanOmitFromDynSym, InputFile *File) {
  Symbol *S;
  bool WasInserted;
  uint8_t Visibility = getVisibility(StOther);
  std::tie(S, WasInserted) =
      insert(Name, Type, Visibility, CanOmitFromDynSym, File);
  // An undefined symbol with non default visibility must be satisfied
  // in the same DSO.
  if (WasInserted || (isa<SharedSymbol>(S) && Visibility != STV_DEFAULT)) {
    replaceSymbol<Undefined>(S, File, Name, Binding, StOther, Type);
    return S;
  }
  if (S->isShared() || S->isLazy() || (S->isUndefined() && Binding != STB_WEAK))
    S->Binding = Binding;
  if (Binding != STB_WEAK) {
    if (auto *SS = dyn_cast<SharedSymbol>(S))
      if (!Config->GcSections)
        SS->getFile<ELFT>().IsNeeded = true;
  }
  if (auto *L = dyn_cast<Lazy>(S)) {
    // An undefined weak will not fetch archive members. See comment on Lazy in
    // Symbols.h for the details.
    if (Binding == STB_WEAK)
      L->Type = Type;
    else if (InputFile *F = L->fetch())
      addFile<ELFT>(F);
  }
  return S;
}

// Using .symver foo,foo@@VER unfortunately creates two symbols: foo and
// foo@@VER. We want to effectively ignore foo, so give precedence to
// foo@@VER.
// FIXME: If users can transition to using
// .symver foo,foo@@@VER
// we can delete this hack.
static int compareVersion(Symbol *S, StringRef Name) {
  bool A = Name.contains("@@");
  bool B = S->getName().contains("@@");
  if (A && !B)
    return 1;
  if (!A && B)
    return -1;
  return 0;
}

// We have a new defined symbol with the specified binding. Return 1 if the new
// symbol should win, -1 if the new symbol should lose, or 0 if both symbols are
// strong defined symbols.
static int compareDefined(Symbol *S, bool WasInserted, uint8_t Binding,
                          StringRef Name) {
  if (WasInserted)
    return 1;
  if (!S->isDefined())
    return 1;
  if (int R = compareVersion(S, Name))
    return R;
  if (Binding == STB_WEAK)
    return -1;
  if (S->isWeak())
    return 1;
  return 0;
}

// We have a new non-common defined symbol with the specified binding. Return 1
// if the new symbol should win, -1 if the new symbol should lose, or 0 if there
// is a conflict. If the new symbol wins, also update the binding.
static int compareDefinedNonCommon(Symbol *S, bool WasInserted, uint8_t Binding,
                                   bool IsAbsolute, uint64_t Value,
                                   StringRef Name) {
  if (int Cmp = compareDefined(S, WasInserted, Binding, Name))
    return Cmp;
  if (auto *R = dyn_cast<Defined>(S)) {
    if (R->Section && isa<BssSection>(R->Section)) {
      // Non-common symbols take precedence over common symbols.
      if (Config->WarnCommon)
        warn("common " + S->getName() + " is overridden");
      return 1;
    }
    if (R->Section == nullptr && Binding == STB_GLOBAL && IsAbsolute &&
        R->Value == Value)
      return -1;
  }
  return 0;
}

Symbol *SymbolTable::addCommon(StringRef N, uint64_t Size, uint32_t Alignment,
                               uint8_t Binding, uint8_t StOther, uint8_t Type,
                               InputFile &File) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(N, Type, getVisibility(StOther),
                                    /*CanOmitFromDynSym*/ false, &File);
  int Cmp = compareDefined(S, WasInserted, Binding, N);
  if (Cmp > 0) {
    auto *Bss = make<BssSection>("COMMON", Size, Alignment);
    Bss->File = &File;
    Bss->Live = !Config->GcSections;
    InputSections.push_back(Bss);

    replaceSymbol<Defined>(S, &File, N, Binding, StOther, Type, 0, Size, Bss);
  } else if (Cmp == 0) {
    auto *D = cast<Defined>(S);
    auto *Bss = dyn_cast_or_null<BssSection>(D->Section);
    if (!Bss) {
      // Non-common symbols take precedence over common symbols.
      if (Config->WarnCommon)
        warn("common " + S->getName() + " is overridden");
      return S;
    }

    if (Config->WarnCommon)
      warn("multiple common of " + D->getName());

    Bss->Alignment = std::max(Bss->Alignment, Alignment);
    if (Size > Bss->Size) {
      D->File = Bss->File = &File;
      D->Size = Bss->Size = Size;
    }
  }
  return S;
}

static void warnOrError(const Twine &Msg) {
  if (Config->AllowMultipleDefinition)
    warn(Msg);
  else
    error(Msg);
}

static void reportDuplicate(Symbol *Sym, InputFile *NewFile) {
  warnOrError("duplicate symbol: " + toString(*Sym) + "\n>>> defined in " +
              toString(Sym->File) + "\n>>> defined in " + toString(NewFile));
}

static void reportDuplicate(Symbol *Sym, InputSectionBase *ErrSec,
                            uint64_t ErrOffset) {
  Defined *D = cast<Defined>(Sym);
  if (!D->Section || !ErrSec) {
    reportDuplicate(Sym, ErrSec ? ErrSec->File : nullptr);
    return;
  }

  // Construct and print an error message in the form of:
  //
  //   ld.lld: error: duplicate symbol: foo
  //   >>> defined at bar.c:30
  //   >>>            bar.o (/home/alice/src/bar.o)
  //   >>> defined at baz.c:563
  //   >>>            baz.o in archive libbaz.a
  auto *Sec1 = cast<InputSectionBase>(D->Section);
  std::string Src1 = Sec1->getSrcMsg(*Sym, D->Value);
  std::string Obj1 = Sec1->getObjMsg(D->Value);
  std::string Src2 = ErrSec->getSrcMsg(*Sym, ErrOffset);
  std::string Obj2 = ErrSec->getObjMsg(ErrOffset);

  std::string Msg = "duplicate symbol: " + toString(*Sym) + "\n>>> defined at ";
  if (!Src1.empty())
    Msg += Src1 + "\n>>>            ";
  Msg += Obj1 + "\n>>> defined at ";
  if (!Src2.empty())
    Msg += Src2 + "\n>>>            ";
  Msg += Obj2;
  warnOrError(Msg);
}

Symbol *SymbolTable::addRegular(StringRef Name, uint8_t StOther, uint8_t Type,
                                uint64_t Value, uint64_t Size, uint8_t Binding,
                                SectionBase *Section, InputFile *File) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name, Type, getVisibility(StOther),
                                    /*CanOmitFromDynSym*/ false, File);
  int Cmp = compareDefinedNonCommon(S, WasInserted, Binding, Section == nullptr,
                                    Value, Name);
  if (Cmp > 0)
    replaceSymbol<Defined>(S, File, Name, Binding, StOther, Type, Value, Size,
                           Section);
  else if (Cmp == 0)
    reportDuplicate(S, dyn_cast_or_null<InputSectionBase>(Section), Value);
  return S;
}

template <typename ELFT>
void SymbolTable::addShared(StringRef Name, SharedFile<ELFT> &File,
                            const typename ELFT::Sym &Sym, uint32_t Alignment,
                            uint32_t VerdefIndex) {
  // DSO symbols do not affect visibility in the output, so we pass STV_DEFAULT
  // as the visibility, which will leave the visibility in the symbol table
  // unchanged.
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name, Sym.getType(), STV_DEFAULT,
                                    /*CanOmitFromDynSym*/ true, &File);
  // Make sure we preempt DSO symbols with default visibility.
  if (Sym.getVisibility() == STV_DEFAULT)
    S->ExportDynamic = true;

  // An undefined symbol with non default visibility must be satisfied
  // in the same DSO.
  if (WasInserted || ((S->isUndefined() || S->isLazy()) &&
                      S->getVisibility() == STV_DEFAULT)) {
    uint8_t Binding = S->Binding;
    bool WasUndefined = S->isUndefined();
    replaceSymbol<SharedSymbol>(S, File, Name, Sym.getBinding(), Sym.st_other,
                                Sym.getType(), Sym.st_value, Sym.st_size,
                                Alignment, VerdefIndex);
    if (!WasInserted) {
      S->Binding = Binding;
      if (!S->isWeak() && !Config->GcSections && WasUndefined)
        File.IsNeeded = true;
    }
  }
}

Symbol *SymbolTable::addBitcode(StringRef Name, uint8_t Binding,
                                uint8_t StOther, uint8_t Type,
                                bool CanOmitFromDynSym, BitcodeFile &F) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) =
      insert(Name, Type, getVisibility(StOther), CanOmitFromDynSym, &F);
  int Cmp = compareDefinedNonCommon(S, WasInserted, Binding,
                                    /*IsAbs*/ false, /*Value*/ 0, Name);
  if (Cmp > 0)
    replaceSymbol<Defined>(S, &F, Name, Binding, StOther, Type, 0, 0, nullptr);
  else if (Cmp == 0)
    reportDuplicate(S, &F);
  return S;
}

Symbol *SymbolTable::find(StringRef Name) {
  auto It = SymMap.find(CachedHashStringRef(Name));
  if (It == SymMap.end())
    return nullptr;
  if (It->second == -1)
    return nullptr;
  return SymVector[It->second];
}

template <class ELFT>
Symbol *SymbolTable::addLazyArchive(StringRef Name, ArchiveFile &F,
                                    const object::Archive::Symbol Sym) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name);
  if (WasInserted) {
    replaceSymbol<LazyArchive>(S, F, Sym, Symbol::UnknownType);
    return S;
  }
  if (!S->isUndefined())
    return S;

  // An undefined weak will not fetch archive members. See comment on Lazy in
  // Symbols.h for the details.
  if (S->isWeak()) {
    replaceSymbol<LazyArchive>(S, F, Sym, S->Type);
    S->Binding = STB_WEAK;
    return S;
  }
  std::pair<MemoryBufferRef, uint64_t> MBInfo = F.getMember(&Sym);
  if (!MBInfo.first.getBuffer().empty())
    addFile<ELFT>(createObjectFile(MBInfo.first, F.getName(), MBInfo.second));
  return S;
}

template <class ELFT>
void SymbolTable::addLazyObject(StringRef Name, LazyObjFile &Obj) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name);
  if (WasInserted) {
    replaceSymbol<LazyObject>(S, Obj, Name, Symbol::UnknownType);
    return;
  }
  if (!S->isUndefined())
    return;

  // See comment for addLazyArchive above.
  if (S->isWeak())
    replaceSymbol<LazyObject>(S, Obj, Name, S->Type);
  else if (InputFile *F = Obj.fetch())
    addFile<ELFT>(F);
}

// If we already saw this symbol, force loading its file.
template <class ELFT> void SymbolTable::fetchIfLazy(StringRef Name) {
  if (Symbol *B = find(Name)) {
    // Mark the symbol not to be eliminated by LTO
    // even if it is a bitcode symbol.
    B->IsUsedInRegularObj = true;
    if (auto *L = dyn_cast<Lazy>(B))
      if (InputFile *File = L->fetch())
        addFile<ELFT>(File);
  }
}

// This function takes care of the case in which shared libraries depend on
// the user program (not the other way, which is usual). Shared libraries
// may have undefined symbols, expecting that the user program provides
// the definitions for them. An example is BSD's __progname symbol.
// We need to put such symbols to the main program's .dynsym so that
// shared libraries can find them.
// Except this, we ignore undefined symbols in DSOs.
template <class ELFT> void SymbolTable::scanShlibUndefined() {
  for (InputFile *F : SharedFiles) {
    for (StringRef U : cast<SharedFile<ELFT>>(F)->getUndefinedSymbols()) {
      Symbol *Sym = find(U);
      if (!Sym || !Sym->isDefined())
        continue;
      Sym->ExportDynamic = true;

      // If -dynamic-list is given, the default version is set to
      // VER_NDX_LOCAL, which prevents a symbol to be exported via .dynsym.
      // Set to VER_NDX_GLOBAL so the symbol will be handled as if it were
      // specified by -dynamic-list.
      Sym->VersionId = VER_NDX_GLOBAL;
    }
  }
}

// Initialize DemangledSyms with a map from demangled symbols to symbol
// objects. Used to handle "extern C++" directive in version scripts.
//
// The map will contain all demangled symbols. That can be very large,
// and in LLD we generally want to avoid do anything for each symbol.
// Then, why are we doing this? Here's why.
//
// Users can use "extern C++ {}" directive to match against demangled
// C++ symbols. For example, you can write a pattern such as
// "llvm::*::foo(int, ?)". Obviously, there's no way to handle this
// other than trying to match a pattern against all demangled symbols.
// So, if "extern C++" feature is used, we need to demangle all known
// symbols.
StringMap<std::vector<Symbol *>> &SymbolTable::getDemangledSyms() {
  if (!DemangledSyms) {
    DemangledSyms.emplace();
    for (Symbol *Sym : SymVector) {
      if (!Sym->isDefined())
        continue;
      if (Optional<std::string> S = demangleItanium(Sym->getName()))
        (*DemangledSyms)[*S].push_back(Sym);
      else
        (*DemangledSyms)[Sym->getName()].push_back(Sym);
    }
  }
  return *DemangledSyms;
}

std::vector<Symbol *> SymbolTable::findByVersion(SymbolVersion Ver) {
  if (Ver.IsExternCpp)
    return getDemangledSyms().lookup(Ver.Name);
  if (Symbol *B = find(Ver.Name))
    if (B->isDefined())
      return {B};
  return {};
}

std::vector<Symbol *> SymbolTable::findAllByVersion(SymbolVersion Ver) {
  std::vector<Symbol *> Res;
  StringMatcher M(Ver.Name);

  if (Ver.IsExternCpp) {
    for (auto &P : getDemangledSyms())
      if (M.match(P.first()))
        Res.insert(Res.end(), P.second.begin(), P.second.end());
    return Res;
  }

  for (Symbol *Sym : SymVector)
    if (Sym->isDefined() && M.match(Sym->getName()))
      Res.push_back(Sym);
  return Res;
}

// If there's only one anonymous version definition in a version
// script file, the script does not actually define any symbol version,
// but just specifies symbols visibilities.
void SymbolTable::handleAnonymousVersion() {
  for (SymbolVersion &Ver : Config->VersionScriptGlobals)
    assignExactVersion(Ver, VER_NDX_GLOBAL, "global");
  for (SymbolVersion &Ver : Config->VersionScriptGlobals)
    assignWildcardVersion(Ver, VER_NDX_GLOBAL);
  for (SymbolVersion &Ver : Config->VersionScriptLocals)
    assignExactVersion(Ver, VER_NDX_LOCAL, "local");
  for (SymbolVersion &Ver : Config->VersionScriptLocals)
    assignWildcardVersion(Ver, VER_NDX_LOCAL);
}

// Handles -dynamic-list.
void SymbolTable::handleDynamicList() {
  for (SymbolVersion &Ver : Config->DynamicList) {
    std::vector<Symbol *> Syms;
    if (Ver.HasWildcard)
      Syms = findAllByVersion(Ver);
    else
      Syms = findByVersion(Ver);

    for (Symbol *B : Syms) {
      if (!Config->Shared)
        B->ExportDynamic = true;
      else if (B->includeInDynsym())
        B->IsPreemptible = true;
    }
  }
}

// Set symbol versions to symbols. This function handles patterns
// containing no wildcard characters.
void SymbolTable::assignExactVersion(SymbolVersion Ver, uint16_t VersionId,
                                     StringRef VersionName) {
  if (Ver.HasWildcard)
    return;

  // Get a list of symbols which we need to assign the version to.
  std::vector<Symbol *> Syms = findByVersion(Ver);
  if (Syms.empty()) {
    if (Config->NoUndefinedVersion)
      error("version script assignment of '" + VersionName + "' to symbol '" +
            Ver.Name + "' failed: symbol not defined");
    return;
  }

  // Assign the version.
  for (Symbol *Sym : Syms) {
    // Skip symbols containing version info because symbol versions
    // specified by symbol names take precedence over version scripts.
    // See parseSymbolVersion().
    if (Sym->getName().contains('@'))
      continue;

    if (Sym->InVersionScript)
      warn("duplicate symbol '" + Ver.Name + "' in version script");
    Sym->VersionId = VersionId;
    Sym->InVersionScript = true;
  }
}

void SymbolTable::assignWildcardVersion(SymbolVersion Ver, uint16_t VersionId) {
  if (!Ver.HasWildcard)
    return;

  // Exact matching takes precendence over fuzzy matching,
  // so we set a version to a symbol only if no version has been assigned
  // to the symbol. This behavior is compatible with GNU.
  for (Symbol *B : findAllByVersion(Ver))
    if (B->VersionId == Config->DefaultSymbolVersion)
      B->VersionId = VersionId;
}

// This function processes version scripts by updating VersionId
// member of symbols.
void SymbolTable::scanVersionScript() {
  // Handle edge cases first.
  handleAnonymousVersion();
  handleDynamicList();

  // Now we have version definitions, so we need to set version ids to symbols.
  // Each version definition has a glob pattern, and all symbols that match
  // with the pattern get that version.

  // First, we assign versions to exact matching symbols,
  // i.e. version definitions not containing any glob meta-characters.
  for (VersionDefinition &V : Config->VersionDefinitions)
    for (SymbolVersion &Ver : V.Globals)
      assignExactVersion(Ver, V.Id, V.Name);

  // Next, we assign versions to fuzzy matching symbols,
  // i.e. version definitions containing glob meta-characters.
  // Note that because the last match takes precedence over previous matches,
  // we iterate over the definitions in the reverse order.
  for (VersionDefinition &V : llvm::reverse(Config->VersionDefinitions))
    for (SymbolVersion &Ver : V.Globals)
      assignWildcardVersion(Ver, V.Id);

  // Symbol themselves might know their versions because symbols
  // can contain versions in the form of <name>@<version>.
  // Let them parse and update their names to exclude version suffix.
  for (Symbol *Sym : SymVector)
    Sym->parseSymbolVersion();
}

template void SymbolTable::addSymbolWrap<ELF32LE>(StringRef);
template void SymbolTable::addSymbolWrap<ELF32BE>(StringRef);
template void SymbolTable::addSymbolWrap<ELF64LE>(StringRef);
template void SymbolTable::addSymbolWrap<ELF64BE>(StringRef);

template Symbol *SymbolTable::addUndefined<ELF32LE>(StringRef);
template Symbol *SymbolTable::addUndefined<ELF32BE>(StringRef);
template Symbol *SymbolTable::addUndefined<ELF64LE>(StringRef);
template Symbol *SymbolTable::addUndefined<ELF64BE>(StringRef);

template Symbol *SymbolTable::addUndefined<ELF32LE>(StringRef, uint8_t, uint8_t,
                                                    uint8_t, bool, InputFile *);
template Symbol *SymbolTable::addUndefined<ELF32BE>(StringRef, uint8_t, uint8_t,
                                                    uint8_t, bool, InputFile *);
template Symbol *SymbolTable::addUndefined<ELF64LE>(StringRef, uint8_t, uint8_t,
                                                    uint8_t, bool, InputFile *);
template Symbol *SymbolTable::addUndefined<ELF64BE>(StringRef, uint8_t, uint8_t,
                                                    uint8_t, bool, InputFile *);

template void SymbolTable::addCombinedLTOObject<ELF32LE>();
template void SymbolTable::addCombinedLTOObject<ELF32BE>();
template void SymbolTable::addCombinedLTOObject<ELF64LE>();
template void SymbolTable::addCombinedLTOObject<ELF64BE>();

template Symbol *
SymbolTable::addLazyArchive<ELF32LE>(StringRef, ArchiveFile &,
                                     const object::Archive::Symbol);
template Symbol *
SymbolTable::addLazyArchive<ELF32BE>(StringRef, ArchiveFile &,
                                     const object::Archive::Symbol);
template Symbol *
SymbolTable::addLazyArchive<ELF64LE>(StringRef, ArchiveFile &,
                                     const object::Archive::Symbol);
template Symbol *
SymbolTable::addLazyArchive<ELF64BE>(StringRef, ArchiveFile &,
                                     const object::Archive::Symbol);

template void SymbolTable::addLazyObject<ELF32LE>(StringRef, LazyObjFile &);
template void SymbolTable::addLazyObject<ELF32BE>(StringRef, LazyObjFile &);
template void SymbolTable::addLazyObject<ELF64LE>(StringRef, LazyObjFile &);
template void SymbolTable::addLazyObject<ELF64BE>(StringRef, LazyObjFile &);

template void SymbolTable::addShared<ELF32LE>(StringRef, SharedFile<ELF32LE> &,
                                              const typename ELF32LE::Sym &,
                                              uint32_t Alignment, uint32_t);
template void SymbolTable::addShared<ELF32BE>(StringRef, SharedFile<ELF32BE> &,
                                              const typename ELF32BE::Sym &,
                                              uint32_t Alignment, uint32_t);
template void SymbolTable::addShared<ELF64LE>(StringRef, SharedFile<ELF64LE> &,
                                              const typename ELF64LE::Sym &,
                                              uint32_t Alignment, uint32_t);
template void SymbolTable::addShared<ELF64BE>(StringRef, SharedFile<ELF64BE> &,
                                              const typename ELF64BE::Sym &,
                                              uint32_t Alignment, uint32_t);

template void SymbolTable::fetchIfLazy<ELF32LE>(StringRef);
template void SymbolTable::fetchIfLazy<ELF32BE>(StringRef);
template void SymbolTable::fetchIfLazy<ELF64LE>(StringRef);
template void SymbolTable::fetchIfLazy<ELF64BE>(StringRef);

template void SymbolTable::scanShlibUndefined<ELF32LE>();
template void SymbolTable::scanShlibUndefined<ELF32BE>();
template void SymbolTable::scanShlibUndefined<ELF64LE>();
template void SymbolTable::scanShlibUndefined<ELF64BE>();
