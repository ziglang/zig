//===- InputFiles.h ---------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_ELF_INPUT_FILES_H
#define LLD_ELF_INPUT_FILES_H

#include "Config.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/LLVM.h"
#include "lld/Common/Reproduce.h"
#include "llvm/ADT/CachedHashString.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/DebugInfo/DWARF/DWARFDebugLine.h"
#include "llvm/IR/Comdat.h"
#include "llvm/Object/Archive.h"
#include "llvm/Object/ELF.h"
#include "llvm/Object/IRObjectFile.h"
#include "llvm/Support/Threading.h"
#include <map>

namespace llvm {
class TarWriter;
struct DILineInfo;
namespace lto {
class InputFile;
}
} // namespace llvm

namespace lld {
namespace elf {
class InputFile;
class InputSectionBase;
}

// Returns "<internal>", "foo.a(bar.o)" or "baz.o".
std::string toString(const elf::InputFile *f);

namespace elf {

using llvm::object::Archive;

class Symbol;

// If -reproduce option is given, all input files are written
// to this tar archive.
extern std::unique_ptr<llvm::TarWriter> tar;

// Opens a given file.
llvm::Optional<MemoryBufferRef> readFile(StringRef path);

// Add symbols in File to the symbol table.
void parseFile(InputFile *file);

// The root class of input files.
class InputFile {
public:
  enum Kind {
    ObjKind,
    SharedKind,
    LazyObjKind,
    ArchiveKind,
    BitcodeKind,
    BinaryKind,
  };

  Kind kind() const { return fileKind; }

  bool isElf() const {
    Kind k = kind();
    return k == ObjKind || k == SharedKind;
  }

  StringRef getName() const { return mb.getBufferIdentifier(); }
  MemoryBufferRef mb;

  // Returns sections. It is a runtime error to call this function
  // on files that don't have the notion of sections.
  ArrayRef<InputSectionBase *> getSections() const {
    assert(fileKind == ObjKind || fileKind == BinaryKind);
    return sections;
  }

  // Returns object file symbols. It is a runtime error to call this
  // function on files of other types.
  ArrayRef<Symbol *> getSymbols() { return getMutableSymbols(); }

  MutableArrayRef<Symbol *> getMutableSymbols() {
    assert(fileKind == BinaryKind || fileKind == ObjKind ||
           fileKind == BitcodeKind);
    return symbols;
  }

  // Filename of .a which contained this file. If this file was
  // not in an archive file, it is the empty string. We use this
  // string for creating error messages.
  std::string archiveName;

  // If this is an architecture-specific file, the following members
  // have ELF type (i.e. ELF{32,64}{LE,BE}) and target machine type.
  ELFKind ekind = ELFNoneKind;
  uint16_t emachine = llvm::ELF::EM_NONE;
  uint8_t osabi = 0;
  uint8_t abiVersion = 0;

  // Cache for toString(). Only toString() should use this member.
  mutable std::string toStringCache;

  std::string getSrcMsg(const Symbol &sym, InputSectionBase &sec,
                        uint64_t offset);

  // True if this is an argument for --just-symbols. Usually false.
  bool justSymbols = false;

  // outSecOff of .got2 in the current file. This is used by PPC32 -fPIC/-fPIE
  // to compute offsets in PLT call stubs.
  uint32_t ppc32Got2OutSecOff = 0;

  // On PPC64 we need to keep track of which files contain small code model
  // relocations that access the .toc section. To minimize the chance of a
  // relocation overflow, files that do contain said relocations should have
  // their .toc sections sorted closer to the .got section than files that do
  // not contain any small code model relocations. Thats because the toc-pointer
  // is defined to point at .got + 0x8000 and the instructions used with small
  // code model relocations support immediates in the range [-0x8000, 0x7FFC],
  // making the addressable range relative to the toc pointer
  // [.got, .got + 0xFFFC].
  bool ppc64SmallCodeModelTocRelocs = false;

  // groupId is used for --warn-backrefs which is an optional error
  // checking feature. All files within the same --{start,end}-group or
  // --{start,end}-lib get the same group ID. Otherwise, each file gets a new
  // group ID. For more info, see checkDependency() in SymbolTable.cpp.
  uint32_t groupId;
  static bool isInGroup;
  static uint32_t nextGroupId;

  // Index of MIPS GOT built for this file.
  llvm::Optional<size_t> mipsGotIndex;

  std::vector<Symbol *> symbols;

protected:
  InputFile(Kind k, MemoryBufferRef m);
  std::vector<InputSectionBase *> sections;

private:
  const Kind fileKind;
};

class ELFFileBase : public InputFile {
public:
  ELFFileBase(Kind k, MemoryBufferRef m);
  static bool classof(const InputFile *f) { return f->isElf(); }

  template <typename ELFT> llvm::object::ELFFile<ELFT> getObj() const {
    return check(llvm::object::ELFFile<ELFT>::create(mb.getBuffer()));
  }

  StringRef getStringTable() const { return stringTable; }

  template <typename ELFT> typename ELFT::SymRange getELFSyms() const {
    return typename ELFT::SymRange(
        reinterpret_cast<const typename ELFT::Sym *>(elfSyms), numELFSyms);
  }
  template <typename ELFT> typename ELFT::SymRange getGlobalELFSyms() const {
    return getELFSyms<ELFT>().slice(firstGlobal);
  }

protected:
  // Initializes this class's member variables.
  template <typename ELFT> void init();

  const void *elfSyms = nullptr;
  size_t numELFSyms = 0;
  uint32_t firstGlobal = 0;
  StringRef stringTable;
};

// .o file.
template <class ELFT> class ObjFile : public ELFFileBase {
  using Elf_Rel = typename ELFT::Rel;
  using Elf_Rela = typename ELFT::Rela;
  using Elf_Sym = typename ELFT::Sym;
  using Elf_Shdr = typename ELFT::Shdr;
  using Elf_Word = typename ELFT::Word;
  using Elf_CGProfile = typename ELFT::CGProfile;

public:
  static bool classof(const InputFile *f) { return f->kind() == ObjKind; }

  llvm::object::ELFFile<ELFT> getObj() const {
    return this->ELFFileBase::getObj<ELFT>();
  }

  ArrayRef<Symbol *> getLocalSymbols();
  ArrayRef<Symbol *> getGlobalSymbols();

  ObjFile(MemoryBufferRef m, StringRef archiveName) : ELFFileBase(ObjKind, m) {
    this->archiveName = archiveName;
  }

  void parse(bool ignoreComdats = false);

  StringRef getShtGroupSignature(ArrayRef<Elf_Shdr> sections,
                                 const Elf_Shdr &sec);

  Symbol &getSymbol(uint32_t symbolIndex) const {
    if (symbolIndex >= this->symbols.size())
      fatal(toString(this) + ": invalid symbol index");
    return *this->symbols[symbolIndex];
  }

  uint32_t getSectionIndex(const Elf_Sym &sym) const;

  template <typename RelT> Symbol &getRelocTargetSym(const RelT &rel) const {
    uint32_t symIndex = rel.getSymbol(config->isMips64EL);
    return getSymbol(symIndex);
  }

  llvm::Optional<llvm::DILineInfo> getDILineInfo(InputSectionBase *, uint64_t);
  llvm::Optional<std::pair<std::string, unsigned>> getVariableLoc(StringRef name);

  // MIPS GP0 value defined by this file. This value represents the gp value
  // used to create the relocatable object and required to support
  // R_MIPS_GPREL16 / R_MIPS_GPREL32 relocations.
  uint32_t mipsGp0 = 0;

  uint32_t andFeatures = 0;

  // Name of source file obtained from STT_FILE symbol value,
  // or empty string if there is no such symbol in object file
  // symbol table.
  StringRef sourceFile;

  // True if the file defines functions compiled with
  // -fsplit-stack. Usually false.
  bool splitStack = false;

  // True if the file defines functions compiled with -fsplit-stack,
  // but had one or more functions with the no_split_stack attribute.
  bool someNoSplitStack = false;

  // Pointer to this input file's .llvm_addrsig section, if it has one.
  const Elf_Shdr *addrsigSec = nullptr;

  // SHT_LLVM_CALL_GRAPH_PROFILE table
  ArrayRef<Elf_CGProfile> cgProfile;

private:
  void initializeSections(bool ignoreComdats);
  void initializeSymbols();
  void initializeJustSymbols();
  void initializeDwarf();
  InputSectionBase *getRelocTarget(const Elf_Shdr &sec);
  InputSectionBase *createInputSection(const Elf_Shdr &sec);
  StringRef getSectionName(const Elf_Shdr &sec);

  bool shouldMerge(const Elf_Shdr &sec);

  // Each ELF symbol contains a section index which the symbol belongs to.
  // However, because the number of bits dedicated for that is limited, a
  // symbol can directly point to a section only when the section index is
  // equal to or smaller than 65280.
  //
  // If an object file contains more than 65280 sections, the file must
  // contain .symtab_shndx section. The section contains an array of
  // 32-bit integers whose size is the same as the number of symbols.
  // Nth symbol's section index is in the Nth entry of .symtab_shndx.
  //
  // The following variable contains the contents of .symtab_shndx.
  // If the section does not exist (which is common), the array is empty.
  ArrayRef<Elf_Word> shndxTable;

  // .shstrtab contents.
  StringRef sectionStringTable;

  // Debugging information to retrieve source file and line for error
  // reporting. Linker may find reasonable number of errors in a
  // single object file, so we cache debugging information in order to
  // parse it only once for each object file we link.
  std::unique_ptr<llvm::DWARFContext> dwarf;
  std::vector<const llvm::DWARFDebugLine::LineTable *> lineTables;
  struct VarLoc {
    const llvm::DWARFDebugLine::LineTable *lt;
    unsigned file;
    unsigned line;
  };
  llvm::DenseMap<StringRef, VarLoc> variableLoc;
  llvm::once_flag initDwarfLine;
};

// LazyObjFile is analogous to ArchiveFile in the sense that
// the file contains lazy symbols. The difference is that
// LazyObjFile wraps a single file instead of multiple files.
//
// This class is used for --start-lib and --end-lib options which
// instruct the linker to link object files between them with the
// archive file semantics.
class LazyObjFile : public InputFile {
public:
  LazyObjFile(MemoryBufferRef m, StringRef archiveName,
              uint64_t offsetInArchive)
      : InputFile(LazyObjKind, m), offsetInArchive(offsetInArchive) {
    this->archiveName = archiveName;
  }

  static bool classof(const InputFile *f) { return f->kind() == LazyObjKind; }

  template <class ELFT> void parse();
  void fetch();

private:
  uint64_t offsetInArchive;
};

// An ArchiveFile object represents a .a file.
class ArchiveFile : public InputFile {
public:
  explicit ArchiveFile(std::unique_ptr<Archive> &&file);
  static bool classof(const InputFile *f) { return f->kind() == ArchiveKind; }
  void parse();

  // Pulls out an object file that contains a definition for Sym and
  // returns it. If the same file was instantiated before, this
  // function does nothing (so we don't instantiate the same file
  // more than once.)
  void fetch(const Archive::Symbol &sym);

private:
  std::unique_ptr<Archive> file;
  llvm::DenseSet<uint64_t> seen;
};

class BitcodeFile : public InputFile {
public:
  BitcodeFile(MemoryBufferRef m, StringRef archiveName,
              uint64_t offsetInArchive);
  static bool classof(const InputFile *f) { return f->kind() == BitcodeKind; }
  template <class ELFT> void parse();
  std::unique_ptr<llvm::lto::InputFile> obj;
};

// .so file.
class SharedFile : public ELFFileBase {
public:
  SharedFile(MemoryBufferRef m, StringRef defaultSoName)
      : ELFFileBase(SharedKind, m), soName(defaultSoName),
        isNeeded(!config->asNeeded) {}

  // This is actually a vector of Elf_Verdef pointers.
  std::vector<const void *> verdefs;

  // If the output file needs Elf_Verneed data structures for this file, this is
  // a vector of Elf_Vernaux version identifiers that map onto the entries in
  // Verdefs, otherwise it is empty.
  std::vector<unsigned> vernauxs;

  static unsigned vernauxNum;

  std::vector<StringRef> dtNeeded;
  std::string soName;

  static bool classof(const InputFile *f) { return f->kind() == SharedKind; }

  template <typename ELFT> void parse();

  // Used for --no-allow-shlib-undefined.
  bool allNeededIsKnown;

  // Used for --as-needed
  bool isNeeded;
};

class BinaryFile : public InputFile {
public:
  explicit BinaryFile(MemoryBufferRef m) : InputFile(BinaryKind, m) {}
  static bool classof(const InputFile *f) { return f->kind() == BinaryKind; }
  void parse();
};

InputFile *createObjectFile(MemoryBufferRef mb, StringRef archiveName = "",
                            uint64_t offsetInArchive = 0);

inline bool isBitcode(MemoryBufferRef mb) {
  return identify_magic(mb.getBuffer()) == llvm::file_magic::bitcode;
}

std::string replaceThinLTOSuffix(StringRef path);

extern std::vector<BinaryFile *> binaryFiles;
extern std::vector<BitcodeFile *> bitcodeFiles;
extern std::vector<LazyObjFile *> lazyObjFiles;
extern std::vector<InputFile *> objectFiles;
extern std::vector<SharedFile *> sharedFiles;

} // namespace elf
} // namespace lld

#endif
