//===- Symbols.h ------------------------------------------------*- C++ -*-===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_WASM_SYMBOLS_H
#define LLD_WASM_SYMBOLS_H

#include "lld/Common/LLVM.h"
#include "llvm/Object/Archive.h"
#include "llvm/Object/Wasm.h"

using llvm::object::Archive;
using llvm::object::WasmSymbol;
using llvm::wasm::WasmExport;
using llvm::wasm::WasmImport;
using llvm::wasm::WasmSignature;

namespace lld {
namespace wasm {

class InputFile;
class InputSegment;

class Symbol {
public:
  enum Kind {
    DefinedFunctionKind,
    DefinedGlobalKind,

    LazyKind,
    UndefinedFunctionKind,
    UndefinedGlobalKind,

    LastDefinedKind = DefinedGlobalKind,
    InvalidKind,
  };

  Symbol(StringRef Name, bool IsLocal)
      : WrittenToSymtab(0), WrittenToNameSec(0), IsLocal(IsLocal), Name(Name) {}

  Kind getKind() const { return SymbolKind; }

  bool isLazy() const { return SymbolKind == LazyKind; }
  bool isDefined() const { return SymbolKind <= LastDefinedKind; }
  bool isUndefined() const {
    return SymbolKind == UndefinedGlobalKind ||
           SymbolKind == UndefinedFunctionKind;
  }
  bool isFunction() const {
    return SymbolKind == DefinedFunctionKind ||
           SymbolKind == UndefinedFunctionKind;
  }
  bool isGlobal() const { return !isFunction(); }
  bool isLocal() const { return IsLocal; }
  bool isWeak() const;
  bool isHidden() const;

  // Returns the symbol name.
  StringRef getName() const { return Name; }

  // Returns the file from which this symbol was created.
  InputFile *getFile() const { return File; }

  uint32_t getGlobalIndex() const;
  uint32_t getFunctionIndex() const;

  bool hasFunctionType() const { return FunctionType != nullptr; }
  const WasmSignature &getFunctionType() const;
  uint32_t getOutputIndex() const;
  uint32_t getTableIndex() const { return TableIndex.getValue(); }

  // Returns the virtual address of a defined global.
  // Only works for globals, not functions.
  uint32_t getVirtualAddress() const;

  // Set the output index of the symbol (in the function or global index
  // space of the output object.
  void setOutputIndex(uint32_t Index);

  // Returns true if a table index has been set for this symbol
  bool hasTableIndex() const { return TableIndex.hasValue(); }

  // Set the table index of the symbol
  void setTableIndex(uint32_t Index);

  void setVirtualAddress(uint32_t VA);

  void update(Kind K, InputFile *F = nullptr, const WasmSymbol *Sym = nullptr,
              const InputSegment *Segment = nullptr,
              const WasmSignature *Sig = nullptr);

  void setArchiveSymbol(const Archive::Symbol &Sym) { ArchiveSymbol = Sym; }
  const Archive::Symbol &getArchiveSymbol() { return ArchiveSymbol; }

  // This bit is used by Writer::writeNameSection() to prevent
  // symbols from being written to the symbol table more than once.
  unsigned WrittenToSymtab : 1;
  unsigned WrittenToNameSec : 1;

protected:
  unsigned IsLocal : 1;

  StringRef Name;
  Archive::Symbol ArchiveSymbol = {nullptr, 0, 0};
  Kind SymbolKind = InvalidKind;
  InputFile *File = nullptr;
  const WasmSymbol *Sym = nullptr;
  const InputSegment *Segment = nullptr;
  llvm::Optional<uint32_t> OutputIndex;
  llvm::Optional<uint32_t> TableIndex;
  llvm::Optional<uint32_t> VirtualAddress;
  const WasmSignature *FunctionType;
};

} // namespace wasm

// Returns a symbol name for an error message.
std::string toString(const wasm::Symbol &Sym);
std::string toString(wasm::Symbol::Kind Kind);

} // namespace lld

#endif
