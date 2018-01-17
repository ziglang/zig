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

#include "lld/Common/LLVM.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/Object/Archive.h"
#include "llvm/Object/Wasm.h"
#include "llvm/Support/MemoryBuffer.h"

#include "WriterUtils.h"

#include <vector>

using llvm::object::Archive;
using llvm::object::WasmObjectFile;
using llvm::object::WasmSection;
using llvm::object::WasmSymbol;
using llvm::wasm::WasmImport;

namespace lld {
namespace wasm {

class Symbol;
class InputSegment;

class InputFile {
public:
  enum Kind {
    ObjectKind,
    ArchiveKind,
  };

  virtual ~InputFile() {}

  // Returns the filename.
  StringRef getName() const { return MB.getBufferIdentifier(); }

  // Reads a file (the constructor doesn't do that).
  virtual void parse() = 0;

  Kind kind() const { return FileKind; }

  // An archive file name if this file is created from an archive.
  StringRef ParentName;

protected:
  InputFile(Kind K, MemoryBufferRef M) : MB(M), FileKind(K) {}
  MemoryBufferRef MB;

private:
  const Kind FileKind;
};

// .a file (ar archive)
class ArchiveFile : public InputFile {
public:
  explicit ArchiveFile(MemoryBufferRef M) : InputFile(ArchiveKind, M) {}
  static bool classof(const InputFile *F) { return F->kind() == ArchiveKind; }

  void addMember(const Archive::Symbol *Sym);

  void parse() override;

private:
  std::unique_ptr<Archive> File;
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

  uint32_t relocateTypeIndex(uint32_t Original) const;
  uint32_t relocateFunctionIndex(uint32_t Original) const;
  uint32_t relocateGlobalIndex(uint32_t Original) const;
  uint32_t relocateTableIndex(uint32_t Original) const;
  uint32_t getRelocatedAddress(uint32_t Index) const;

  // Returns true if the given function index is an imported function,
  // as opposed to the locally defined function.
  bool isImportedFunction(uint32_t Index) const;

  size_t NumFunctionImports() const { return FunctionImports; }
  size_t NumGlobalImports() const { return GlobalImports; }

  int32_t FunctionIndexOffset = 0;
  const WasmSection *CodeSection = nullptr;
  std::vector<OutputRelocation> CodeRelocations;
  int32_t CodeOffset = 0;
  const WasmSection *DataSection = nullptr;

  std::vector<uint32_t> TypeMap;
  std::vector<InputSegment *> Segments;

  ArrayRef<Symbol *> getSymbols() { return Symbols; }
  ArrayRef<Symbol *> getTableSymbols() { return TableSymbols; }

private:
  Symbol *createDefined(const WasmSymbol &Sym,
                        const InputSegment *Segment = nullptr);
  Symbol *createUndefined(const WasmSymbol &Sym);
  void initializeSymbols();
  InputSegment *getSegment(const WasmSymbol &WasmSym);
  Symbol *getFunctionSymbol(uint32_t FunctionIndex) const;
  Symbol *getTableSymbol(uint32_t TableIndex) const;
  Symbol *getGlobalSymbol(uint32_t GlobalIndex) const;

  // List of all symbols referenced or defined by this file.
  std::vector<Symbol *> Symbols;

  // List of all function symbols indexed by the function index space
  std::vector<Symbol *> FunctionSymbols;

  // List of all global symbols indexed by the global index space
  std::vector<Symbol *> GlobalSymbols;

  // List of all indirect symbols indexed by table index space.
  std::vector<Symbol *> TableSymbols;

  uint32_t GlobalImports = 0;
  uint32_t FunctionImports = 0;
  std::unique_ptr<WasmObjectFile> WasmObj;
};

// Opens a given file.
llvm::Optional<MemoryBufferRef> readFile(StringRef Path);

} // namespace wasm

std::string toString(const wasm::InputFile *File);

} // namespace lld

#endif
