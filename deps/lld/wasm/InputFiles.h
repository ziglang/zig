//===- InputFiles.h ---------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_WASM_INPUT_FILES_H
#define LLD_WASM_INPUT_FILES_H

#include "Symbols.h"
#include "lld/Common/LLVM.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/LTO/LTO.h"
#include "llvm/Object/Archive.h"
#include "llvm/Object/Wasm.h"
#include "llvm/Support/MemoryBuffer.h"
#include <vector>

namespace lld {
namespace wasm {

class InputChunk;
class InputFunction;
class InputSegment;
class InputGlobal;
class InputEvent;
class InputSection;

class InputFile {
public:
  enum Kind {
    ObjectKind,
    ArchiveKind,
    BitcodeKind,
  };

  virtual ~InputFile() {}

  // Returns the filename.
  StringRef getName() const { return MB.getBufferIdentifier(); }

  // Reads a file (the constructor doesn't do that).
  virtual void parse() = 0;

  Kind kind() const { return FileKind; }

  // An archive file name if this file is created from an archive.
  StringRef ArchiveName;

  ArrayRef<Symbol *> getSymbols() const { return Symbols; }

protected:
  InputFile(Kind K, MemoryBufferRef M) : MB(M), FileKind(K) {}
  MemoryBufferRef MB;

  // List of all symbols referenced or defined by this file.
  std::vector<Symbol *> Symbols;

private:
  const Kind FileKind;
};

// .a file (ar archive)
class ArchiveFile : public InputFile {
public:
  explicit ArchiveFile(MemoryBufferRef M) : InputFile(ArchiveKind, M) {}
  static bool classof(const InputFile *F) { return F->kind() == ArchiveKind; }

  void addMember(const llvm::object::Archive::Symbol *Sym);

  void parse() override;

private:
  std::unique_ptr<llvm::object::Archive> File;
  llvm::DenseSet<uint64_t> Seen;
};

// .o file (wasm object file)
class ObjFile : public InputFile {
public:
  explicit ObjFile(MemoryBufferRef M) : InputFile(ObjectKind, M) {}
  static bool classof(const InputFile *F) { return F->kind() == ObjectKind; }

  void parse() override;

  // Returns the underlying wasm file.
  const WasmObjectFile *getWasmObj() const { return WasmObj.get(); }

  void dumpInfo() const;

  uint32_t calcNewIndex(const WasmRelocation &Reloc) const;
  uint32_t calcNewValue(const WasmRelocation &Reloc) const;
  uint32_t calcNewAddend(const WasmRelocation &Reloc) const;
  uint32_t calcExpectedValue(const WasmRelocation &Reloc) const;

  const WasmSection *CodeSection = nullptr;
  const WasmSection *DataSection = nullptr;

  // Maps input type indices to output type indices
  std::vector<uint32_t> TypeMap;
  std::vector<bool> TypeIsUsed;
  // Maps function indices to table indices
  std::vector<uint32_t> TableEntries;
  std::vector<bool> UsedComdats;
  std::vector<InputSegment *> Segments;
  std::vector<InputFunction *> Functions;
  std::vector<InputGlobal *> Globals;
  std::vector<InputEvent *> Events;
  std::vector<InputSection *> CustomSections;
  llvm::DenseMap<uint32_t, InputSection *> CustomSectionsByIndex;

  Symbol *getSymbol(uint32_t Index) const { return Symbols[Index]; }
  FunctionSymbol *getFunctionSymbol(uint32_t Index) const;
  DataSymbol *getDataSymbol(uint32_t Index) const;
  GlobalSymbol *getGlobalSymbol(uint32_t Index) const;
  SectionSymbol *getSectionSymbol(uint32_t Index) const;
  EventSymbol *getEventSymbol(uint32_t Index) const;

private:
  Symbol *createDefined(const WasmSymbol &Sym);
  Symbol *createUndefined(const WasmSymbol &Sym);

  bool isExcludedByComdat(InputChunk *Chunk) const;

  std::unique_ptr<WasmObjectFile> WasmObj;
};

class BitcodeFile : public InputFile {
public:
  explicit BitcodeFile(MemoryBufferRef M) : InputFile(BitcodeKind, M) {}
  static bool classof(const InputFile *F) { return F->kind() == BitcodeKind; }

  void parse() override;
  std::unique_ptr<llvm::lto::InputFile> Obj;
};

// Will report a fatal() error if the input buffer is not a valid bitcode
// or was object file.
InputFile *createObjectFile(MemoryBufferRef MB);

// Opens a given file.
llvm::Optional<MemoryBufferRef> readFile(StringRef Path);

} // namespace wasm

std::string toString(const wasm::InputFile *File);

} // namespace lld

#endif
