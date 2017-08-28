//===- SymbolTable.h --------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_ELF_SYMBOL_TABLE_H
#define LLD_ELF_SYMBOL_TABLE_H

#include "InputFiles.h"
#include "LTO.h"
#include "Strings.h"
#include "llvm/ADT/CachedHashString.h"
#include "llvm/ADT/DenseMap.h"

namespace lld {
namespace elf {

struct Symbol;

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
template <class ELFT> class SymbolTable {
  typedef typename ELFT::Sym Elf_Sym;

public:
  void addFile(InputFile *File);
  void addCombinedLTOObject();
  void addSymbolAlias(StringRef Alias, StringRef Name);
  void addSymbolWrap(StringRef Name);
  void applySymbolRenames();

  ArrayRef<Symbol *> getSymbols() const { return SymVector; }
  ArrayRef<ObjectFile<ELFT> *> getObjectFiles() const { return ObjectFiles; }
  ArrayRef<BinaryFile *> getBinaryFiles() const { return BinaryFiles; }
  ArrayRef<SharedFile<ELFT> *> getSharedFiles() const { return SharedFiles; }

  DefinedRegular *addAbsolute(StringRef Name,
                              uint8_t Visibility = llvm::ELF::STV_HIDDEN,
                              uint8_t Binding = llvm::ELF::STB_GLOBAL);
  DefinedRegular *addIgnored(StringRef Name,
                             uint8_t Visibility = llvm::ELF::STV_HIDDEN);

  Symbol *addUndefined(StringRef Name);
  Symbol *addUndefined(StringRef Name, bool IsLocal, uint8_t Binding,
                       uint8_t StOther, uint8_t Type, bool CanOmitFromDynSym,
                       InputFile *File);

  Symbol *addRegular(StringRef Name, uint8_t StOther, uint8_t Type,
                     uint64_t Value, uint64_t Size, uint8_t Binding,
                     SectionBase *Section, InputFile *File);

  void addShared(SharedFile<ELFT> *F, StringRef Name, const Elf_Sym &Sym,
                 const typename ELFT::Verdef *Verdef);

  Symbol *addLazyArchive(ArchiveFile *F, const llvm::object::Archive::Symbol S);
  void addLazyObject(StringRef Name, LazyObjectFile &Obj);
  Symbol *addBitcode(StringRef Name, uint8_t Binding, uint8_t StOther,
                     uint8_t Type, bool CanOmitFromDynSym, BitcodeFile *File);

  Symbol *addCommon(StringRef N, uint64_t Size, uint32_t Alignment,
                    uint8_t Binding, uint8_t StOther, uint8_t Type,
                    InputFile *File);

  std::pair<Symbol *, bool> insert(StringRef Name);
  std::pair<Symbol *, bool> insert(StringRef Name, uint8_t Type,
                                   uint8_t Visibility, bool CanOmitFromDynSym,
                                   InputFile *File);

  void scanUndefinedFlags();
  void scanShlibUndefined();
  void scanVersionScript();

  SymbolBody *find(StringRef Name);
  SymbolBody *findInCurrentDSO(StringRef Name);

  void trace(StringRef Name);

private:
  std::vector<SymbolBody *> findByVersion(SymbolVersion Ver);
  std::vector<SymbolBody *> findAllByVersion(SymbolVersion Ver);

  llvm::StringMap<std::vector<SymbolBody *>> &getDemangledSyms();
  void handleAnonymousVersion();
  void assignExactVersion(SymbolVersion Ver, uint16_t VersionId,
                          StringRef VersionName);
  void assignWildcardVersion(SymbolVersion Ver, uint16_t VersionId);

  struct SymIndex {
    SymIndex(int Idx, bool Traced) : Idx(Idx), Traced(Traced) {}
    int Idx : 31;
    unsigned Traced : 1;
  };

  // The order the global symbols are in is not defined. We can use an arbitrary
  // order, but it has to be reproducible. That is true even when cross linking.
  // The default hashing of StringRef produces different results on 32 and 64
  // bit systems so we use a map to a vector. That is arbitrary, deterministic
  // but a bit inefficient.
  // FIXME: Experiment with passing in a custom hashing or sorting the symbols
  // once symbol resolution is finished.
  llvm::DenseMap<llvm::CachedHashStringRef, SymIndex> Symtab;
  std::vector<Symbol *> SymVector;

  // Comdat groups define "link once" sections. If two comdat groups have the
  // same name, only one of them is linked, and the other is ignored. This set
  // is used to uniquify them.
  llvm::DenseSet<llvm::CachedHashStringRef> ComdatGroups;

  std::vector<ObjectFile<ELFT> *> ObjectFiles;
  std::vector<SharedFile<ELFT> *> SharedFiles;
  std::vector<BitcodeFile *> BitcodeFiles;
  std::vector<BinaryFile *> BinaryFiles;

  // Set of .so files to not link the same shared object file more than once.
  llvm::DenseSet<StringRef> SoNames;

  // A map from demangled symbol names to their symbol objects.
  // This mapping is 1:N because two symbols with different versions
  // can have the same name. We use this map to handle "extern C++ {}"
  // directive in version scripts.
  llvm::Optional<llvm::StringMap<std::vector<SymbolBody *>>> DemangledSyms;

  // For LTO.
  std::unique_ptr<BitcodeCompiler> LTO;
};

template <class ELFT> struct Symtab { static SymbolTable<ELFT> *X; };
template <class ELFT> SymbolTable<ELFT> *Symtab<ELFT>::X;

} // namespace elf
} // namespace lld

#endif
