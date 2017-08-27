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
#include "Error.h"
#include "LinkerScript.h"
#include "Memory.h"
#include "Symbols.h"
#include "llvm/ADT/STLExtras.h"

using namespace llvm;
using namespace llvm::object;
using namespace llvm::ELF;

using namespace lld;
using namespace lld::elf;

// All input object files must be for the same architecture
// (e.g. it does not make sense to link x86 object files with
// MIPS object files.) This function checks for that error.
template <class ELFT> static bool isCompatible(InputFile *F) {
  if (!isa<ELFFileBase<ELFT>>(F) && !isa<BitcodeFile>(F))
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
    error(toString(F) + " is incompatible with " + toString(Config->FirstElf));
  return false;
}

// Add symbols in File to the symbol table.
template <class ELFT> void SymbolTable<ELFT>::addFile(InputFile *File) {
  if (!Config->FirstElf && isa<ELFFileBase<ELFT>>(File))
    Config->FirstElf = File;

  if (!isCompatible<ELFT>(File))
    return;

  // Binary file
  if (auto *F = dyn_cast<BinaryFile>(File)) {
    BinaryFiles.push_back(F);
    F->parse<ELFT>();
    return;
  }

  // .a file
  if (auto *F = dyn_cast<ArchiveFile>(File)) {
    F->parse<ELFT>();
    return;
  }

  // Lazy object file
  if (auto *F = dyn_cast<LazyObjectFile>(File)) {
    F->parse<ELFT>();
    return;
  }

  if (Config->Trace)
    message(toString(File));

  // .so file
  if (auto *F = dyn_cast<SharedFile<ELFT>>(File)) {
    // DSOs are uniquified not by filename but by soname.
    F->parseSoName();
    if (ErrorCount || !SoNames.insert(F->SoName).second)
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
  auto *F = cast<ObjectFile<ELFT>>(File);
  ObjectFiles.push_back(F);
  F->parse(ComdatGroups);
}

// This function is where all the optimizations of link-time
// optimization happens. When LTO is in use, some input files are
// not in native object file format but in the LLVM bitcode format.
// This function compiles bitcode files into a few big native files
// using LLVM functions and replaces bitcode symbols with the results.
// Because all bitcode files that consist of a program are passed
// to the compiler at once, it can do whole-program optimization.
template <class ELFT> void SymbolTable<ELFT>::addCombinedLTOObject() {
  if (BitcodeFiles.empty())
    return;

  // Compile bitcode files and replace bitcode symbols.
  LTO.reset(new BitcodeCompiler);
  for (BitcodeFile *F : BitcodeFiles)
    LTO->add(*F);

  for (InputFile *File : LTO->compile()) {
    ObjectFile<ELFT> *Obj = cast<ObjectFile<ELFT>>(File);
    DenseSet<CachedHashStringRef> DummyGroups;
    Obj->parse(DummyGroups);
    ObjectFiles.push_back(Obj);
  }
}

template <class ELFT>
DefinedRegular *SymbolTable<ELFT>::addAbsolute(StringRef Name,
                                               uint8_t Visibility,
                                               uint8_t Binding) {
  Symbol *Sym =
      addRegular(Name, Visibility, STT_NOTYPE, 0, 0, Binding, nullptr, nullptr);
  return cast<DefinedRegular>(Sym->body());
}

// Add Name as an "ignored" symbol. An ignored symbol is a regular
// linker-synthesized defined symbol, but is only defined if needed.
template <class ELFT>
DefinedRegular *SymbolTable<ELFT>::addIgnored(StringRef Name,
                                              uint8_t Visibility) {
  SymbolBody *S = find(Name);
  if (!S || S->isInCurrentDSO())
    return nullptr;
  return addAbsolute(Name, Visibility);
}

// Set a flag for --trace-symbol so that we can print out a log message
// if a new symbol with the same name is inserted into the symbol table.
template <class ELFT> void SymbolTable<ELFT>::trace(StringRef Name) {
  Symtab.insert({CachedHashStringRef(Name), {-1, true}});
}

// Rename SYM as __wrap_SYM. The original symbol is preserved as __real_SYM.
// Used to implement --wrap.
template <class ELFT> void SymbolTable<ELFT>::addSymbolWrap(StringRef Name) {
  SymbolBody *B = find(Name);
  if (!B)
    return;
  Symbol *Sym = B->symbol();
  Symbol *Real = addUndefined(Saver.save("__real_" + Name));
  Symbol *Wrap = addUndefined(Saver.save("__wrap_" + Name));

  // Tell LTO not to eliminate this symbol
  Wrap->IsUsedInRegularObj = true;

  Config->RenamedSymbols[Real] = {Sym, Real->Binding};
  Config->RenamedSymbols[Sym] = {Wrap, Sym->Binding};
}

// Creates alias for symbol. Used to implement --defsym=ALIAS=SYM.
template <class ELFT>
void SymbolTable<ELFT>::addSymbolAlias(StringRef Alias, StringRef Name) {
  SymbolBody *B = find(Name);
  if (!B) {
    error("-defsym: undefined symbol: " + Name);
    return;
  }
  Symbol *Sym = B->symbol();
  Symbol *AliasSym = addUndefined(Alias);

  // Tell LTO not to eliminate this symbol
  Sym->IsUsedInRegularObj = true;
  Config->RenamedSymbols[AliasSym] = {Sym, AliasSym->Binding};
}

// Apply symbol renames created by -wrap and -defsym. The renames are created
// before LTO in addSymbolWrap() and addSymbolAlias() to have a chance to inform
// LTO (if LTO is running) not to include these symbols in IPO. Now that the
// symbols are finalized, we can perform the replacement.
template <class ELFT> void SymbolTable<ELFT>::applySymbolRenames() {
  for (auto &KV : Config->RenamedSymbols) {
    Symbol *Dst = KV.first;
    Symbol *Src = KV.second.Target;
    Dst->body()->copy(Src->body());
    Dst->Binding = KV.second.OriginalBinding;
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
template <class ELFT>
std::pair<Symbol *, bool> SymbolTable<ELFT>::insert(StringRef Name) {
  // <name>@@<version> means the symbol is the default version. In that
  // case <name>@@<version> will be used to resolve references to <name>.
  size_t Pos = Name.find("@@");
  if (Pos != StringRef::npos)
    Name = Name.take_front(Pos);

  auto P = Symtab.insert(
      {CachedHashStringRef(Name), SymIndex((int)SymVector.size(), false)});
  SymIndex &V = P.first->second;
  bool IsNew = P.second;

  if (V.Idx == -1) {
    IsNew = true;
    V = SymIndex((int)SymVector.size(), true);
  }

  Symbol *Sym;
  if (IsNew) {
    Sym = make<Symbol>();
    Sym->InVersionScript = false;
    Sym->Binding = STB_WEAK;
    Sym->Visibility = STV_DEFAULT;
    Sym->IsUsedInRegularObj = false;
    Sym->ExportDynamic = false;
    Sym->Traced = V.Traced;
    Sym->VersionId = Config->DefaultSymbolVersion;
    SymVector.push_back(Sym);
  } else {
    Sym = SymVector[V.Idx];
  }
  return {Sym, IsNew};
}

// Find an existing symbol or create and insert a new one, then apply the given
// attributes.
template <class ELFT>
std::pair<Symbol *, bool>
SymbolTable<ELFT>::insert(StringRef Name, uint8_t Type, uint8_t Visibility,
                          bool CanOmitFromDynSym, InputFile *File) {
  bool IsUsedInRegularObj = !File || File->kind() == InputFile::ObjectKind;
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name);

  // Merge in the new symbol's visibility.
  S->Visibility = getMinVisibility(S->Visibility, Visibility);

  if (!CanOmitFromDynSym && (Config->Shared || Config->ExportDynamic))
    S->ExportDynamic = true;

  if (IsUsedInRegularObj)
    S->IsUsedInRegularObj = true;

  if (!WasInserted && S->body()->Type != SymbolBody::UnknownType &&
      ((Type == STT_TLS) != S->body()->isTls())) {
    error("TLS attribute mismatch: " + toString(*S->body()) +
          "\n>>> defined in " + toString(S->body()->File) +
          "\n>>> defined in " + toString(File));
  }

  return {S, WasInserted};
}

template <class ELFT> Symbol *SymbolTable<ELFT>::addUndefined(StringRef Name) {
  return addUndefined(Name, /*IsLocal=*/false, STB_GLOBAL, STV_DEFAULT,
                      /*Type*/ 0,
                      /*CanOmitFromDynSym*/ false, /*File*/ nullptr);
}

static uint8_t getVisibility(uint8_t StOther) { return StOther & 3; }

template <class ELFT>
Symbol *SymbolTable<ELFT>::addUndefined(StringRef Name, bool IsLocal,
                                        uint8_t Binding, uint8_t StOther,
                                        uint8_t Type, bool CanOmitFromDynSym,
                                        InputFile *File) {
  Symbol *S;
  bool WasInserted;
  uint8_t Visibility = getVisibility(StOther);
  std::tie(S, WasInserted) =
      insert(Name, Type, Visibility, CanOmitFromDynSym, File);
  // An undefined symbol with non default visibility must be satisfied
  // in the same DSO.
  if (WasInserted ||
      (isa<SharedSymbol>(S->body()) && Visibility != STV_DEFAULT)) {
    S->Binding = Binding;
    replaceBody<Undefined>(S, Name, IsLocal, StOther, Type, File);
    return S;
  }
  if (Binding != STB_WEAK) {
    SymbolBody *B = S->body();
    if (B->isShared() || B->isLazy() || B->isUndefined())
      S->Binding = Binding;
    if (auto *SS = dyn_cast<SharedSymbol>(B))
      cast<SharedFile<ELFT>>(SS->File)->IsUsed = true;
  }
  if (auto *L = dyn_cast<Lazy>(S->body())) {
    // An undefined weak will not fetch archive members, but we have to remember
    // its type. See also comment in addLazyArchive.
    if (S->isWeak())
      L->Type = Type;
    else if (InputFile *F = L->fetch())
      addFile(F);
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
  if (Name.find("@@") != StringRef::npos &&
      S->body()->getName().find("@@") == StringRef::npos)
    return 1;
  if (Name.find("@@") == StringRef::npos &&
      S->body()->getName().find("@@") != StringRef::npos)
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
  SymbolBody *Body = S->body();
  if (!Body->isInCurrentDSO())
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
template <typename ELFT>
static int compareDefinedNonCommon(Symbol *S, bool WasInserted, uint8_t Binding,
                                   bool IsAbsolute, typename ELFT::uint Value,
                                   StringRef Name) {
  if (int Cmp = compareDefined(S, WasInserted, Binding, Name)) {
    if (Cmp > 0)
      S->Binding = Binding;
    return Cmp;
  }
  SymbolBody *B = S->body();
  if (isa<DefinedCommon>(B)) {
    // Non-common symbols take precedence over common symbols.
    if (Config->WarnCommon)
      warn("common " + S->body()->getName() + " is overridden");
    return 1;
  } else if (auto *R = dyn_cast<DefinedRegular>(B)) {
    if (R->Section == nullptr && Binding == STB_GLOBAL && IsAbsolute &&
        R->Value == Value)
      return -1;
  }
  return 0;
}

template <class ELFT>
Symbol *SymbolTable<ELFT>::addCommon(StringRef N, uint64_t Size,
                                     uint32_t Alignment, uint8_t Binding,
                                     uint8_t StOther, uint8_t Type,
                                     InputFile *File) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(N, Type, getVisibility(StOther),
                                    /*CanOmitFromDynSym*/ false, File);
  int Cmp = compareDefined(S, WasInserted, Binding, N);
  if (Cmp > 0) {
    S->Binding = Binding;
    replaceBody<DefinedCommon>(S, N, Size, Alignment, StOther, Type, File);
  } else if (Cmp == 0) {
    auto *C = dyn_cast<DefinedCommon>(S->body());
    if (!C) {
      // Non-common symbols take precedence over common symbols.
      if (Config->WarnCommon)
        warn("common " + S->body()->getName() + " is overridden");
      return S;
    }

    if (Config->WarnCommon)
      warn("multiple common of " + S->body()->getName());

    Alignment = C->Alignment = std::max(C->Alignment, Alignment);
    if (Size > C->Size)
      replaceBody<DefinedCommon>(S, N, Size, Alignment, StOther, Type, File);
  }
  return S;
}

static void warnOrError(const Twine &Msg) {
  if (Config->AllowMultipleDefinition)
    warn(Msg);
  else
    error(Msg);
}

static void reportDuplicate(SymbolBody *Sym, InputFile *NewFile) {
  warnOrError("duplicate symbol: " + toString(*Sym) + "\n>>> defined in " +
              toString(Sym->File) + "\n>>> defined in " + toString(NewFile));
}

template <class ELFT>
static void reportDuplicate(SymbolBody *Sym, InputSectionBase *ErrSec,
                            typename ELFT::uint ErrOffset) {
  DefinedRegular *D = dyn_cast<DefinedRegular>(Sym);
  if (!D || !D->Section || !ErrSec) {
    reportDuplicate(Sym, ErrSec ? ErrSec->getFile<ELFT>() : nullptr);
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
  std::string Src1 = Sec1->getSrcMsg<ELFT>(D->Value);
  std::string Obj1 = Sec1->getObjMsg<ELFT>(D->Value);
  std::string Src2 = ErrSec->getSrcMsg<ELFT>(ErrOffset);
  std::string Obj2 = ErrSec->getObjMsg<ELFT>(ErrOffset);

  std::string Msg = "duplicate symbol: " + toString(*Sym) + "\n>>> defined at ";
  if (!Src1.empty())
    Msg += Src1 + "\n>>>            ";
  Msg += Obj1 + "\n>>> defined at ";
  if (!Src2.empty())
    Msg += Src2 + "\n>>>            ";
  Msg += Obj2;
  warnOrError(Msg);
}

template <typename ELFT>
Symbol *SymbolTable<ELFT>::addRegular(StringRef Name, uint8_t StOther,
                                      uint8_t Type, uint64_t Value,
                                      uint64_t Size, uint8_t Binding,
                                      SectionBase *Section, InputFile *File) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name, Type, getVisibility(StOther),
                                    /*CanOmitFromDynSym*/ false, File);
  int Cmp = compareDefinedNonCommon<ELFT>(S, WasInserted, Binding,
                                          Section == nullptr, Value, Name);
  if (Cmp > 0)
    replaceBody<DefinedRegular>(S, Name, /*IsLocal=*/false, StOther, Type,
                                Value, Size, Section, File);
  else if (Cmp == 0)
    reportDuplicate<ELFT>(S->body(),
                          dyn_cast_or_null<InputSectionBase>(Section), Value);
  return S;
}

template <typename ELFT>
void SymbolTable<ELFT>::addShared(SharedFile<ELFT> *File, StringRef Name,
                                  const Elf_Sym &Sym,
                                  const typename ELFT::Verdef *Verdef) {
  // DSO symbols do not affect visibility in the output, so we pass STV_DEFAULT
  // as the visibility, which will leave the visibility in the symbol table
  // unchanged.
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name, Sym.getType(), STV_DEFAULT,
                                    /*CanOmitFromDynSym*/ true, File);
  // Make sure we preempt DSO symbols with default visibility.
  if (Sym.getVisibility() == STV_DEFAULT)
    S->ExportDynamic = true;

  SymbolBody *Body = S->body();
  // An undefined symbol with non default visibility must be satisfied
  // in the same DSO.
  if (WasInserted ||
      (isa<Undefined>(Body) && Body->getVisibility() == STV_DEFAULT)) {
    replaceBody<SharedSymbol>(S, File, Name, Sym.st_other, Sym.getType(), &Sym,
                              Verdef);
    if (!S->isWeak())
      File->IsUsed = true;
  }
}

template <class ELFT>
Symbol *SymbolTable<ELFT>::addBitcode(StringRef Name, uint8_t Binding,
                                      uint8_t StOther, uint8_t Type,
                                      bool CanOmitFromDynSym, BitcodeFile *F) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) =
      insert(Name, Type, getVisibility(StOther), CanOmitFromDynSym, F);
  int Cmp = compareDefinedNonCommon<ELFT>(S, WasInserted, Binding,
                                          /*IsAbs*/ false, /*Value*/ 0, Name);
  if (Cmp > 0)
    replaceBody<DefinedRegular>(S, Name, /*IsLocal=*/false, StOther, Type, 0, 0,
                                nullptr, F);
  else if (Cmp == 0)
    reportDuplicate(S->body(), F);
  return S;
}

template <class ELFT> SymbolBody *SymbolTable<ELFT>::find(StringRef Name) {
  auto It = Symtab.find(CachedHashStringRef(Name));
  if (It == Symtab.end())
    return nullptr;
  SymIndex V = It->second;
  if (V.Idx == -1)
    return nullptr;
  return SymVector[V.Idx]->body();
}

template <class ELFT>
SymbolBody *SymbolTable<ELFT>::findInCurrentDSO(StringRef Name) {
  if (SymbolBody *S = find(Name))
    if (S->isInCurrentDSO())
      return S;
  return nullptr;
}

template <class ELFT>
Symbol *SymbolTable<ELFT>::addLazyArchive(ArchiveFile *F,
                                          const object::Archive::Symbol Sym) {
  Symbol *S;
  bool WasInserted;
  StringRef Name = Sym.getName();
  std::tie(S, WasInserted) = insert(Name);
  if (WasInserted) {
    replaceBody<LazyArchive>(S, *F, Sym, SymbolBody::UnknownType);
    return S;
  }
  if (!S->body()->isUndefined())
    return S;

  // Weak undefined symbols should not fetch members from archives. If we were
  // to keep old symbol we would not know that an archive member was available
  // if a strong undefined symbol shows up afterwards in the link. If a strong
  // undefined symbol never shows up, this lazy symbol will get to the end of
  // the link and must be treated as the weak undefined one. We already marked
  // this symbol as used when we added it to the symbol table, but we also need
  // to preserve its type. FIXME: Move the Type field to Symbol.
  if (S->isWeak()) {
    replaceBody<LazyArchive>(S, *F, Sym, S->body()->Type);
    return S;
  }
  std::pair<MemoryBufferRef, uint64_t> MBInfo = F->getMember(&Sym);
  if (!MBInfo.first.getBuffer().empty())
    addFile(createObjectFile(MBInfo.first, F->getName(), MBInfo.second));
  return S;
}

template <class ELFT>
void SymbolTable<ELFT>::addLazyObject(StringRef Name, LazyObjectFile &Obj) {
  Symbol *S;
  bool WasInserted;
  std::tie(S, WasInserted) = insert(Name);
  if (WasInserted) {
    replaceBody<LazyObject>(S, Name, Obj, SymbolBody::UnknownType);
    return;
  }
  if (!S->body()->isUndefined())
    return;

  // See comment for addLazyArchive above.
  if (S->isWeak())
    replaceBody<LazyObject>(S, Name, Obj, S->body()->Type);
  else if (InputFile *F = Obj.fetch())
    addFile(F);
}

// Process undefined (-u) flags by loading lazy symbols named by those flags.
template <class ELFT> void SymbolTable<ELFT>::scanUndefinedFlags() {
  for (StringRef S : Config->Undefined)
    if (auto *L = dyn_cast_or_null<Lazy>(find(S)))
      if (InputFile *File = L->fetch())
        addFile(File);
}

// This function takes care of the case in which shared libraries depend on
// the user program (not the other way, which is usual). Shared libraries
// may have undefined symbols, expecting that the user program provides
// the definitions for them. An example is BSD's __progname symbol.
// We need to put such symbols to the main program's .dynsym so that
// shared libraries can find them.
// Except this, we ignore undefined symbols in DSOs.
template <class ELFT> void SymbolTable<ELFT>::scanShlibUndefined() {
  for (SharedFile<ELFT> *File : SharedFiles) {
    for (StringRef U : File->getUndefinedSymbols()) {
      SymbolBody *Sym = find(U);
      if (!Sym || !Sym->isDefined())
        continue;
      Sym->symbol()->ExportDynamic = true;

      // If -dynamic-list is given, the default version is set to
      // VER_NDX_LOCAL, which prevents a symbol to be exported via .dynsym.
      // Set to VER_NDX_GLOBAL so the symbol will be handled as if it were
      // specified by -dynamic-list.
      Sym->symbol()->VersionId = VER_NDX_GLOBAL;
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
template <class ELFT>
StringMap<std::vector<SymbolBody *>> &SymbolTable<ELFT>::getDemangledSyms() {
  if (!DemangledSyms) {
    DemangledSyms.emplace();
    for (Symbol *Sym : SymVector) {
      SymbolBody *B = Sym->body();
      if (B->isUndefined())
        continue;
      if (Optional<std::string> S = demangle(B->getName()))
        (*DemangledSyms)[*S].push_back(B);
      else
        (*DemangledSyms)[B->getName()].push_back(B);
    }
  }
  return *DemangledSyms;
}

template <class ELFT>
std::vector<SymbolBody *> SymbolTable<ELFT>::findByVersion(SymbolVersion Ver) {
  if (Ver.IsExternCpp)
    return getDemangledSyms().lookup(Ver.Name);
  if (SymbolBody *B = find(Ver.Name))
    if (!B->isUndefined())
      return {B};
  return {};
}

template <class ELFT>
std::vector<SymbolBody *>
SymbolTable<ELFT>::findAllByVersion(SymbolVersion Ver) {
  std::vector<SymbolBody *> Res;
  StringMatcher M(Ver.Name);

  if (Ver.IsExternCpp) {
    for (auto &P : getDemangledSyms())
      if (M.match(P.first()))
        Res.insert(Res.end(), P.second.begin(), P.second.end());
    return Res;
  }

  for (Symbol *Sym : SymVector) {
    SymbolBody *B = Sym->body();
    if (!B->isUndefined() && M.match(B->getName()))
      Res.push_back(B);
  }
  return Res;
}

// If there's only one anonymous version definition in a version
// script file, the script does not actually define any symbol version,
// but just specifies symbols visibilities.
template <class ELFT> void SymbolTable<ELFT>::handleAnonymousVersion() {
  for (SymbolVersion &Ver : Config->VersionScriptGlobals)
    assignExactVersion(Ver, VER_NDX_GLOBAL, "global");
  for (SymbolVersion &Ver : Config->VersionScriptGlobals)
    assignWildcardVersion(Ver, VER_NDX_GLOBAL);
  for (SymbolVersion &Ver : Config->VersionScriptLocals)
    assignExactVersion(Ver, VER_NDX_LOCAL, "local");
  for (SymbolVersion &Ver : Config->VersionScriptLocals)
    assignWildcardVersion(Ver, VER_NDX_LOCAL);
}

// Set symbol versions to symbols. This function handles patterns
// containing no wildcard characters.
template <class ELFT>
void SymbolTable<ELFT>::assignExactVersion(SymbolVersion Ver,
                                           uint16_t VersionId,
                                           StringRef VersionName) {
  if (Ver.HasWildcard)
    return;

  // Get a list of symbols which we need to assign the version to.
  std::vector<SymbolBody *> Syms = findByVersion(Ver);
  if (Syms.empty()) {
    if (Config->NoUndefinedVersion)
      error("version script assignment of '" + VersionName + "' to symbol '" +
            Ver.Name + "' failed: symbol not defined");
    return;
  }

  // Assign the version.
  for (SymbolBody *B : Syms) {
    // Skip symbols containing version info because symbol versions
    // specified by symbol names take precedence over version scripts.
    // See parseSymbolVersion().
    if (B->getName().find('@') != StringRef::npos)
      continue;

    Symbol *Sym = B->symbol();
    if (Sym->InVersionScript)
      warn("duplicate symbol '" + Ver.Name + "' in version script");
    Sym->VersionId = VersionId;
    Sym->InVersionScript = true;
  }
}

template <class ELFT>
void SymbolTable<ELFT>::assignWildcardVersion(SymbolVersion Ver,
                                              uint16_t VersionId) {
  if (!Ver.HasWildcard)
    return;

  // Exact matching takes precendence over fuzzy matching,
  // so we set a version to a symbol only if no version has been assigned
  // to the symbol. This behavior is compatible with GNU.
  for (SymbolBody *B : findAllByVersion(Ver))
    if (B->symbol()->VersionId == Config->DefaultSymbolVersion)
      B->symbol()->VersionId = VersionId;
}

// This function processes version scripts by updating VersionId
// member of symbols.
template <class ELFT> void SymbolTable<ELFT>::scanVersionScript() {
  // Handle edge cases first.
  handleAnonymousVersion();

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
    Sym->body()->parseSymbolVersion();
}

template class elf::SymbolTable<ELF32LE>;
template class elf::SymbolTable<ELF32BE>;
template class elf::SymbolTable<ELF64LE>;
template class elf::SymbolTable<ELF64BE>;
