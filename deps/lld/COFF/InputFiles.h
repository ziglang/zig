//===- InputFiles.h ---------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_COFF_INPUT_FILES_H
#define LLD_COFF_INPUT_FILES_H

#include "Config.h"
#include "lld/Common/LLVM.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/LTO/LTO.h"
#include "llvm/Object/Archive.h"
#include "llvm/Object/COFF.h"
#include "llvm/Support/StringSaver.h"
#include <memory>
#include <set>
#include <vector>

namespace llvm {
namespace pdb {
class DbiModuleDescriptorBuilder;
}
}

namespace lld {
namespace coff {

std::vector<MemoryBufferRef> getArchiveMembers(llvm::object::Archive *File);

using llvm::COFF::IMAGE_FILE_MACHINE_UNKNOWN;
using llvm::COFF::MachineTypes;
using llvm::object::Archive;
using llvm::object::COFFObjectFile;
using llvm::object::COFFSymbolRef;
using llvm::object::coff_import_header;
using llvm::object::coff_section;

class Chunk;
class Defined;
class DefinedImportData;
class DefinedImportThunk;
class Lazy;
class SectionChunk;
class Symbol;
class Undefined;

// The root class of input files.
class InputFile {
public:
  enum Kind { ArchiveKind, ObjectKind, ImportKind, BitcodeKind };
  Kind kind() const { return FileKind; }
  virtual ~InputFile() {}

  // Returns the filename.
  StringRef getName() const { return MB.getBufferIdentifier(); }

  // Reads a file (the constructor doesn't do that).
  virtual void parse() = 0;

  // Returns the CPU type this file was compiled to.
  virtual MachineTypes getMachineType() { return IMAGE_FILE_MACHINE_UNKNOWN; }

  MemoryBufferRef MB;

  // An archive file name if this file is created from an archive.
  StringRef ParentName;

  // Returns .drectve section contents if exist.
  StringRef getDirectives() { return StringRef(Directives).trim(); }

protected:
  InputFile(Kind K, MemoryBufferRef M) : MB(M), FileKind(K) {}

  std::string Directives;

private:
  const Kind FileKind;
};

// .lib or .a file.
class ArchiveFile : public InputFile {
public:
  explicit ArchiveFile(MemoryBufferRef M);
  static bool classof(const InputFile *F) { return F->kind() == ArchiveKind; }
  void parse() override;

  // Enqueues an archive member load for the given symbol. If we've already
  // enqueued a load for the same archive member, this function does nothing,
  // which ensures that we don't load the same member more than once.
  void addMember(const Archive::Symbol *Sym);

private:
  std::unique_ptr<Archive> File;
  std::string Filename;
  llvm::DenseSet<uint64_t> Seen;
};

// .obj or .o file. This may be a member of an archive file.
class ObjFile : public InputFile {
public:
  explicit ObjFile(MemoryBufferRef M) : InputFile(ObjectKind, M) {}
  static bool classof(const InputFile *F) { return F->kind() == ObjectKind; }
  void parse() override;
  MachineTypes getMachineType() override;
  ArrayRef<Chunk *> getChunks() { return Chunks; }
  ArrayRef<SectionChunk *> getDebugChunks() { return DebugChunks; }
  ArrayRef<Symbol *> getSymbols() { return Symbols; }

  // Returns a Symbol object for the SymbolIndex'th symbol in the
  // underlying object file.
  Symbol *getSymbol(uint32_t SymbolIndex) {
    return Symbols[SymbolIndex];
  }

  // Returns the underying COFF file.
  COFFObjectFile *getCOFFObj() { return COFFObj.get(); }

  static std::vector<ObjFile *> Instances;

  // True if this object file is compatible with SEH.
  // COFF-specific and x86-only.
  bool SEHCompat = false;

  // The symbol table indexes of the safe exception handlers.
  // COFF-specific and x86-only.
  ArrayRef<llvm::support::ulittle32_t> SXData;

  // Pointer to the PDB module descriptor builder. Various debug info records
  // will reference object files by "module index", which is here. Things like
  // source files and section contributions are also recorded here. Will be null
  // if we are not producing a PDB.
  llvm::pdb::DbiModuleDescriptorBuilder *ModuleDBI = nullptr;

private:
  void initializeChunks();
  void initializeSymbols();

  SectionChunk *
  readSection(uint32_t SectionNumber,
              const llvm::object::coff_aux_section_definition *Def);

  void readAssociativeDefinition(
      COFFSymbolRef COFFSym,
      const llvm::object::coff_aux_section_definition *Def);

  llvm::Optional<Symbol *>
  createDefined(COFFSymbolRef Sym,
                std::vector<const llvm::object::coff_aux_section_definition *>
                    &ComdatDefs);
  Symbol *createRegular(COFFSymbolRef Sym);
  Symbol *createUndefined(COFFSymbolRef Sym);

  std::unique_ptr<COFFObjectFile> COFFObj;

  // List of all chunks defined by this file. This includes both section
  // chunks and non-section chunks for common symbols.
  std::vector<Chunk *> Chunks;

  // CodeView debug info sections.
  std::vector<SectionChunk *> DebugChunks;

  // This vector contains the same chunks as Chunks, but they are
  // indexed such that you can get a SectionChunk by section index.
  // Nonexistent section indices are filled with null pointers.
  // (Because section number is 1-based, the first slot is always a
  // null pointer.)
  std::vector<SectionChunk *> SparseChunks;

  // This vector contains a list of all symbols defined or referenced by this
  // file. They are indexed such that you can get a Symbol by symbol
  // index. Nonexistent indices (which are occupied by auxiliary
  // symbols in the real symbol table) are filled with null pointers.
  std::vector<Symbol *> Symbols;
};

// This type represents import library members that contain DLL names
// and symbols exported from the DLLs. See Microsoft PE/COFF spec. 7
// for details about the format.
class ImportFile : public InputFile {
public:
  explicit ImportFile(MemoryBufferRef M)
      : InputFile(ImportKind, M), Live(!Config->DoGC) {}

  static bool classof(const InputFile *F) { return F->kind() == ImportKind; }

  static std::vector<ImportFile *> Instances;

  DefinedImportData *ImpSym = nullptr;
  DefinedImportThunk *ThunkSym = nullptr;
  std::string DLLName;

private:
  void parse() override;

public:
  StringRef ExternalName;
  const coff_import_header *Hdr;
  Chunk *Location = nullptr;

  // We want to eliminate dllimported symbols if no one actually refers them.
  // This "Live" bit is used to keep track of which import library members
  // are actually in use.
  //
  // If the Live bit is turned off by MarkLive, Writer will ignore dllimported
  // symbols provided by this import library member.
  bool Live;
};

// Used for LTO.
class BitcodeFile : public InputFile {
public:
  explicit BitcodeFile(MemoryBufferRef M) : InputFile(BitcodeKind, M) {}
  static bool classof(const InputFile *F) { return F->kind() == BitcodeKind; }
  ArrayRef<Symbol *> getSymbols() { return SymbolBodies; }
  MachineTypes getMachineType() override;
  static std::vector<BitcodeFile *> Instances;
  std::unique_ptr<llvm::lto::InputFile> Obj;

private:
  void parse() override;

  std::vector<Symbol *> SymbolBodies;
};
} // namespace coff

std::string toString(const coff::InputFile *File);
} // namespace lld

#endif
