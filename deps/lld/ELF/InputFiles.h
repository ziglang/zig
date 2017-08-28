//===- InputFiles.h ---------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_ELF_INPUT_FILES_H
#define LLD_ELF_INPUT_FILES_H

#include "Config.h"
#include "Error.h"
#include "InputSection.h"
#include "Symbols.h"

#include "lld/Core/LLVM.h"
#include "lld/Core/Reproduce.h"
#include "llvm/ADT/CachedHashString.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/IR/Comdat.h"
#include "llvm/Object/Archive.h"
#include "llvm/Object/ELF.h"
#include "llvm/Object/IRObjectFile.h"
#include "llvm/Support/Threading.h"

#include <map>

namespace llvm {
class DWARFDebugLine;
class TarWriter;
struct DILineInfo;
namespace lto {
class InputFile;
}
} // namespace llvm

namespace lld {
namespace elf {
class InputFile;
}

// Returns "(internal)", "foo.a(bar.o)" or "baz.o".
std::string toString(const elf::InputFile *F);

namespace elf {

using llvm::object::Archive;

class Lazy;
class SymbolBody;

// If -reproduce option is given, all input files are written
// to this tar archive.
extern llvm::TarWriter *Tar;

// Opens a given file.
llvm::Optional<MemoryBufferRef> readFile(StringRef Path);

// The root class of input files.
class InputFile {
public:
  enum Kind {
    ObjectKind,
    SharedKind,
    LazyObjectKind,
    ArchiveKind,
    BitcodeKind,
    BinaryKind,
  };

  Kind kind() const { return FileKind; }

  StringRef getName() const { return MB.getBufferIdentifier(); }
  MemoryBufferRef MB;

  // Returns sections. It is a runtime error to call this function
  // on files that don't have the notion of sections.
  ArrayRef<InputSectionBase *> getSections() const {
    assert(FileKind == ObjectKind || FileKind == BinaryKind);
    return Sections;
  }

  // Filename of .a which contained this file. If this file was
  // not in an archive file, it is the empty string. We use this
  // string for creating error messages.
  StringRef ArchiveName;

  // If this is an architecture-specific file, the following members
  // have ELF type (i.e. ELF{32,64}{LE,BE}) and target machine type.
  ELFKind EKind = ELFNoneKind;
  uint16_t EMachine = llvm::ELF::EM_NONE;
  uint8_t OSABI = 0;

  // Cache for toString(). Only toString() should use this member.
  mutable std::string ToStringCache;

protected:
  InputFile(Kind K, MemoryBufferRef M);
  std::vector<InputSectionBase *> Sections;

private:
  const Kind FileKind;
};

template <typename ELFT> class ELFFileBase : public InputFile {
public:
  typedef typename ELFT::Shdr Elf_Shdr;
  typedef typename ELFT::Sym Elf_Sym;
  typedef typename ELFT::Word Elf_Word;
  typedef typename ELFT::SymRange Elf_Sym_Range;

  ELFFileBase(Kind K, MemoryBufferRef M);
  static bool classof(const InputFile *F) {
    Kind K = F->kind();
    return K == ObjectKind || K == SharedKind;
  }

  llvm::object::ELFFile<ELFT> getObj() const {
    return llvm::object::ELFFile<ELFT>(MB.getBuffer());
  }

  StringRef getStringTable() const { return StringTable; }

  uint32_t getSectionIndex(const Elf_Sym &Sym) const;

  Elf_Sym_Range getGlobalSymbols();

protected:
  ArrayRef<Elf_Sym> Symbols;
  uint32_t FirstNonLocal = 0;
  ArrayRef<Elf_Word> SymtabSHNDX;
  StringRef StringTable;
  void initSymtab(ArrayRef<Elf_Shdr> Sections, const Elf_Shdr *Symtab);
};

// .o file.
template <class ELFT> class ObjectFile : public ELFFileBase<ELFT> {
  typedef ELFFileBase<ELFT> Base;
  typedef typename ELFT::Rel Elf_Rel;
  typedef typename ELFT::Rela Elf_Rela;
  typedef typename ELFT::Sym Elf_Sym;
  typedef typename ELFT::Shdr Elf_Shdr;
  typedef typename ELFT::Word Elf_Word;

  StringRef getShtGroupSignature(ArrayRef<Elf_Shdr> Sections,
                                 const Elf_Shdr &Sec);
  ArrayRef<Elf_Word> getShtGroupEntries(const Elf_Shdr &Sec);

public:
  static bool classof(const InputFile *F) {
    return F->kind() == Base::ObjectKind;
  }

  ArrayRef<SymbolBody *> getSymbols();
  ArrayRef<SymbolBody *> getLocalSymbols();

  ObjectFile(MemoryBufferRef M, StringRef ArchiveName);
  void parse(llvm::DenseSet<llvm::CachedHashStringRef> &ComdatGroups);

  InputSectionBase *getSection(const Elf_Sym &Sym) const;

  SymbolBody &getSymbolBody(uint32_t SymbolIndex) const {
    if (SymbolIndex >= SymbolBodies.size())
      fatal(toString(this) + ": invalid symbol index");
    return *SymbolBodies[SymbolIndex];
  }

  template <typename RelT>
  SymbolBody &getRelocTargetSym(const RelT &Rel) const {
    uint32_t SymIndex = Rel.getSymbol(Config->IsMips64EL);
    return getSymbolBody(SymIndex);
  }

  // Returns source line information for a given offset.
  // If no information is available, returns "".
  std::string getLineInfo(InputSectionBase *S, uint64_t Offset);
  llvm::Optional<llvm::DILineInfo> getDILineInfo(InputSectionBase *, uint64_t);

  // MIPS GP0 value defined by this file. This value represents the gp value
  // used to create the relocatable object and required to support
  // R_MIPS_GPREL16 / R_MIPS_GPREL32 relocations.
  uint32_t MipsGp0 = 0;

  // Name of source file obtained from STT_FILE symbol value,
  // or empty string if there is no such symbol in object file
  // symbol table.
  StringRef SourceFile;

private:
  void
  initializeSections(llvm::DenseSet<llvm::CachedHashStringRef> &ComdatGroups);
  void initializeSymbols();
  void initializeDwarfLine();
  InputSectionBase *getRelocTarget(const Elf_Shdr &Sec);
  InputSectionBase *createInputSection(const Elf_Shdr &Sec);
  StringRef getSectionName(const Elf_Shdr &Sec);

  bool shouldMerge(const Elf_Shdr &Sec);
  SymbolBody *createSymbolBody(const Elf_Sym *Sym);

  // List of all symbols referenced or defined by this file.
  std::vector<SymbolBody *> SymbolBodies;

  // .shstrtab contents.
  StringRef SectionStringTable;

  // Debugging information to retrieve source file and line for error
  // reporting. Linker may find reasonable number of errors in a
  // single object file, so we cache debugging information in order to
  // parse it only once for each object file we link.
  std::unique_ptr<llvm::DWARFDebugLine> DwarfLine;
  llvm::once_flag InitDwarfLine;
};

// LazyObjectFile is analogous to ArchiveFile in the sense that
// the file contains lazy symbols. The difference is that
// LazyObjectFile wraps a single file instead of multiple files.
//
// This class is used for --start-lib and --end-lib options which
// instruct the linker to link object files between them with the
// archive file semantics.
class LazyObjectFile : public InputFile {
public:
  LazyObjectFile(MemoryBufferRef M, StringRef ArchiveName,
                 uint64_t OffsetInArchive)
      : InputFile(LazyObjectKind, M), OffsetInArchive(OffsetInArchive) {
    this->ArchiveName = ArchiveName;
  }

  static bool classof(const InputFile *F) {
    return F->kind() == LazyObjectKind;
  }

  template <class ELFT> void parse();
  MemoryBufferRef getBuffer();
  InputFile *fetch();

private:
  std::vector<StringRef> getSymbols();
  template <class ELFT> std::vector<StringRef> getElfSymbols();
  std::vector<StringRef> getBitcodeSymbols();

  bool Seen = false;
  uint64_t OffsetInArchive;
};

// An ArchiveFile object represents a .a file.
class ArchiveFile : public InputFile {
public:
  explicit ArchiveFile(std::unique_ptr<Archive> &&File);
  static bool classof(const InputFile *F) { return F->kind() == ArchiveKind; }
  template <class ELFT> void parse();
  ArrayRef<Symbol *> getSymbols() { return Symbols; }

  // Returns a memory buffer for a given symbol and the offset in the archive
  // for the member. An empty memory buffer and an offset of zero
  // is returned if we have already returned the same memory buffer.
  // (So that we don't instantiate same members more than once.)
  std::pair<MemoryBufferRef, uint64_t> getMember(const Archive::Symbol *Sym);

private:
  std::unique_ptr<Archive> File;
  llvm::DenseSet<uint64_t> Seen;
  std::vector<Symbol *> Symbols;
};

class BitcodeFile : public InputFile {
public:
  BitcodeFile(MemoryBufferRef M, StringRef ArchiveName,
              uint64_t OffsetInArchive);
  static bool classof(const InputFile *F) { return F->kind() == BitcodeKind; }
  template <class ELFT>
  void parse(llvm::DenseSet<llvm::CachedHashStringRef> &ComdatGroups);
  ArrayRef<Symbol *> getSymbols() { return Symbols; }
  std::unique_ptr<llvm::lto::InputFile> Obj;

private:
  std::vector<Symbol *> Symbols;
};

// .so file.
template <class ELFT> class SharedFile : public ELFFileBase<ELFT> {
  typedef ELFFileBase<ELFT> Base;
  typedef typename ELFT::Dyn Elf_Dyn;
  typedef typename ELFT::Shdr Elf_Shdr;
  typedef typename ELFT::Sym Elf_Sym;
  typedef typename ELFT::SymRange Elf_Sym_Range;
  typedef typename ELFT::Verdef Elf_Verdef;
  typedef typename ELFT::Versym Elf_Versym;

  std::vector<StringRef> Undefs;
  const Elf_Shdr *VersymSec = nullptr;
  const Elf_Shdr *VerdefSec = nullptr;

public:
  std::string SoName;

  const Elf_Shdr *getSection(const Elf_Sym &Sym) const;
  llvm::ArrayRef<StringRef> getUndefinedSymbols() { return Undefs; }

  static bool classof(const InputFile *F) {
    return F->kind() == Base::SharedKind;
  }

  SharedFile(MemoryBufferRef M, StringRef DefaultSoName);

  void parseSoName();
  void parseRest();
  std::vector<const Elf_Verdef *> parseVerdefs(const Elf_Versym *&Versym);

  struct NeededVer {
    // The string table offset of the version name in the output file.
    size_t StrTab;

    // The version identifier for this version name.
    uint16_t Index;
  };

  // Mapping from Elf_Verdef data structures to information about Elf_Vernaux
  // data structures in the output file.
  std::map<const Elf_Verdef *, NeededVer> VerdefMap;

  // Used for --as-needed
  bool AsNeeded = false;
  bool IsUsed = false;
  bool isNeeded() const { return !AsNeeded || IsUsed; }
};

class BinaryFile : public InputFile {
public:
  explicit BinaryFile(MemoryBufferRef M) : InputFile(BinaryKind, M) {}
  static bool classof(const InputFile *F) { return F->kind() == BinaryKind; }
  template <class ELFT> void parse();
};

InputFile *createObjectFile(MemoryBufferRef MB, StringRef ArchiveName = "",
                            uint64_t OffsetInArchive = 0);
InputFile *createSharedFile(MemoryBufferRef MB, StringRef DefaultSoName);

} // namespace elf
} // namespace lld

#endif
