//===- InputFiles.h ---------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
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

namespace llvm {
class TarWriter;
}

namespace lld {
namespace wasm {

class InputChunk;
class InputFunction;
class InputSegment;
class InputGlobal;
class InputEvent;
class InputSection;

// If --reproduce option is given, all input files are written
// to this tar archive.
extern std::unique_ptr<llvm::TarWriter> tar;

class InputFile {
public:
  enum Kind {
    ObjectKind,
    SharedKind,
    ArchiveKind,
    BitcodeKind,
  };

  virtual ~InputFile() {}

  // Returns the filename.
  StringRef getName() const { return mb.getBufferIdentifier(); }

  Kind kind() const { return fileKind; }

  // An archive file name if this file is created from an archive.
  StringRef archiveName;

  ArrayRef<Symbol *> getSymbols() const { return symbols; }

  MutableArrayRef<Symbol *> getMutableSymbols() { return symbols; }

protected:
  InputFile(Kind k, MemoryBufferRef m) : mb(m), fileKind(k) {}
  MemoryBufferRef mb;

  // List of all symbols referenced or defined by this file.
  std::vector<Symbol *> symbols;

private:
  const Kind fileKind;
};

// .a file (ar archive)
class ArchiveFile : public InputFile {
public:
  explicit ArchiveFile(MemoryBufferRef m) : InputFile(ArchiveKind, m) {}
  static bool classof(const InputFile *f) { return f->kind() == ArchiveKind; }

  void addMember(const llvm::object::Archive::Symbol *sym);

  void parse();

private:
  std::unique_ptr<llvm::object::Archive> file;
  llvm::DenseSet<uint64_t> seen;
};

// .o file (wasm object file)
class ObjFile : public InputFile {
public:
  explicit ObjFile(MemoryBufferRef m, StringRef archiveName)
      : InputFile(ObjectKind, m) {
    this->archiveName = archiveName;
  }
  static bool classof(const InputFile *f) { return f->kind() == ObjectKind; }

  void parse(bool ignoreComdats = false);

  // Returns the underlying wasm file.
  const WasmObjectFile *getWasmObj() const { return wasmObj.get(); }

  void dumpInfo() const;

  uint32_t calcNewIndex(const WasmRelocation &reloc) const;
  uint32_t calcNewValue(const WasmRelocation &reloc) const;
  uint32_t calcNewAddend(const WasmRelocation &reloc) const;
  uint32_t calcExpectedValue(const WasmRelocation &reloc) const;
  Symbol *getSymbol(const WasmRelocation &reloc) const {
    return symbols[reloc.Index];
  };

  const WasmSection *codeSection = nullptr;
  const WasmSection *dataSection = nullptr;

  // Maps input type indices to output type indices
  std::vector<uint32_t> typeMap;
  std::vector<bool> typeIsUsed;
  // Maps function indices to table indices
  std::vector<uint32_t> tableEntries;
  std::vector<bool> keptComdats;
  std::vector<InputSegment *> segments;
  std::vector<InputFunction *> functions;
  std::vector<InputGlobal *> globals;
  std::vector<InputEvent *> events;
  std::vector<InputSection *> customSections;
  llvm::DenseMap<uint32_t, InputSection *> customSectionsByIndex;

  Symbol *getSymbol(uint32_t index) const { return symbols[index]; }
  FunctionSymbol *getFunctionSymbol(uint32_t index) const;
  DataSymbol *getDataSymbol(uint32_t index) const;
  GlobalSymbol *getGlobalSymbol(uint32_t index) const;
  SectionSymbol *getSectionSymbol(uint32_t index) const;
  EventSymbol *getEventSymbol(uint32_t index) const;

private:
  Symbol *createDefined(const WasmSymbol &sym);
  Symbol *createUndefined(const WasmSymbol &sym, bool isCalledDirectly);

  bool isExcludedByComdat(InputChunk *chunk) const;

  std::unique_ptr<WasmObjectFile> wasmObj;
};

// .so file.
class SharedFile : public InputFile {
public:
  explicit SharedFile(MemoryBufferRef m) : InputFile(SharedKind, m) {}
  static bool classof(const InputFile *f) { return f->kind() == SharedKind; }
};

// .bc file
class BitcodeFile : public InputFile {
public:
  explicit BitcodeFile(MemoryBufferRef m, StringRef archiveName)
      : InputFile(BitcodeKind, m) {
    this->archiveName = archiveName;
  }
  static bool classof(const InputFile *f) { return f->kind() == BitcodeKind; }

  void parse();
  std::unique_ptr<llvm::lto::InputFile> obj;
};

// Will report a fatal() error if the input buffer is not a valid bitcode
// or wasm object file.
InputFile *createObjectFile(MemoryBufferRef mb, StringRef archiveName = "");

// Opens a given file.
llvm::Optional<MemoryBufferRef> readFile(StringRef path);

} // namespace wasm

std::string toString(const wasm::InputFile *file);

} // namespace lld

#endif
