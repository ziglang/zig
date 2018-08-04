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

#include "Config.h"
#include "lld/Common/LLVM.h"
#include "llvm/Object/Archive.h"
#include "llvm/Object/Wasm.h"

using llvm::object::Archive;
using llvm::object::WasmSymbol;
using llvm::wasm::WasmGlobal;
using llvm::wasm::WasmGlobalType;
using llvm::wasm::WasmSignature;
using llvm::wasm::WasmSymbolType;

namespace lld {
namespace wasm {

class InputFile;
class InputChunk;
class InputSegment;
class InputFunction;
class InputGlobal;
class InputSection;

#define INVALID_INDEX UINT32_MAX

// The base class for real symbol classes.
class Symbol {
public:
  enum Kind {
    DefinedFunctionKind,
    DefinedDataKind,
    DefinedGlobalKind,
    SectionKind,
    UndefinedFunctionKind,
    UndefinedDataKind,
    UndefinedGlobalKind,
    LazyKind,
  };

  Kind kind() const { return SymbolKind; }

  bool isDefined() const {
    return SymbolKind == DefinedFunctionKind || SymbolKind == DefinedDataKind ||
           SymbolKind == DefinedGlobalKind || SymbolKind == SectionKind;
  }

  bool isUndefined() const {
    return SymbolKind == UndefinedFunctionKind ||
           SymbolKind == UndefinedDataKind || SymbolKind == UndefinedGlobalKind;
  }

  bool isLazy() const { return SymbolKind == LazyKind; }

  bool isLocal() const;
  bool isWeak() const;
  bool isHidden() const;

  // Returns the symbol name.
  StringRef getName() const { return Name; }

  // Returns the file from which this symbol was created.
  InputFile *getFile() const { return File; }

  InputChunk *getChunk() const;

  // Indicates that the section or import for this symbol will be included in
  // the final image.
  bool isLive() const;

  // Marks the symbol's InputChunk as Live, so that it will be included in the
  // final image.
  void markLive();

  void setHidden(bool IsHidden);

  // Get/set the index in the output symbol table.  This is only used for
  // relocatable output.
  uint32_t getOutputSymbolIndex() const;
  void setOutputSymbolIndex(uint32_t Index);

  WasmSymbolType getWasmType() const;
  bool isExported() const;

  // True if this symbol was referenced by a regular (non-bitcode) object.
  unsigned IsUsedInRegularObj : 1;
  unsigned ForceExport : 1;

protected:
  Symbol(StringRef Name, Kind K, uint32_t Flags, InputFile *F)
      : IsUsedInRegularObj(false), ForceExport(false), Name(Name),
        SymbolKind(K), Flags(Flags), File(F), Referenced(!Config->GcSections) {}

  StringRef Name;
  Kind SymbolKind;
  uint32_t Flags;
  InputFile *File;
  uint32_t OutputSymbolIndex = INVALID_INDEX;
  bool Referenced;
};

class FunctionSymbol : public Symbol {
public:
  static bool classof(const Symbol *S) {
    return S->kind() == DefinedFunctionKind ||
           S->kind() == UndefinedFunctionKind;
  }

  // Get/set the table index
  void setTableIndex(uint32_t Index);
  uint32_t getTableIndex() const;
  bool hasTableIndex() const;

  // Get/set the function index
  uint32_t getFunctionIndex() const;
  void setFunctionIndex(uint32_t Index);
  bool hasFunctionIndex() const;

  const WasmSignature *FunctionType;

protected:
  FunctionSymbol(StringRef Name, Kind K, uint32_t Flags, InputFile *F,
                 const WasmSignature *Type)
      : Symbol(Name, K, Flags, F), FunctionType(Type) {}

  uint32_t TableIndex = INVALID_INDEX;
  uint32_t FunctionIndex = INVALID_INDEX;
};

class DefinedFunction : public FunctionSymbol {
public:
  DefinedFunction(StringRef Name, uint32_t Flags, InputFile *F,
                  InputFunction *Function);

  static bool classof(const Symbol *S) {
    return S->kind() == DefinedFunctionKind;
  }

  InputFunction *Function;
};

class UndefinedFunction : public FunctionSymbol {
public:
  UndefinedFunction(StringRef Name, uint32_t Flags, InputFile *File = nullptr,
                    const WasmSignature *Type = nullptr)
      : FunctionSymbol(Name, UndefinedFunctionKind, Flags, File, Type) {}

  static bool classof(const Symbol *S) {
    return S->kind() == UndefinedFunctionKind;
  }
};

class SectionSymbol : public Symbol {
public:
  static bool classof(const Symbol *S) { return S->kind() == SectionKind; }

  SectionSymbol(StringRef Name, uint32_t Flags, const InputSection *S,
                InputFile *F = nullptr)
      : Symbol(Name, SectionKind, Flags, F), Section(S) {}

  const InputSection *Section;

  uint32_t getOutputSectionIndex() const;
  void setOutputSectionIndex(uint32_t Index);

protected:
  uint32_t OutputSectionIndex = INVALID_INDEX;
};

class DataSymbol : public Symbol {
public:
  static bool classof(const Symbol *S) {
    return S->kind() == DefinedDataKind || S->kind() == UndefinedDataKind;
  }

protected:
  DataSymbol(StringRef Name, Kind K, uint32_t Flags, InputFile *F)
      : Symbol(Name, K, Flags, F) {}
};

class DefinedData : public DataSymbol {
public:
  // Constructor for regular data symbols originating from input files.
  DefinedData(StringRef Name, uint32_t Flags, InputFile *F,
              InputSegment *Segment, uint32_t Offset, uint32_t Size)
      : DataSymbol(Name, DefinedDataKind, Flags, F), Segment(Segment),
        Offset(Offset), Size(Size) {}

  // Constructor for linker synthetic data symbols.
  DefinedData(StringRef Name, uint32_t Flags)
      : DataSymbol(Name, DefinedDataKind, Flags, nullptr) {}

  static bool classof(const Symbol *S) { return S->kind() == DefinedDataKind; }

  // Returns the output virtual address of a defined data symbol.
  uint32_t getVirtualAddress() const;
  void setVirtualAddress(uint32_t VA);

  // Returns the offset of a defined data symbol within its OutputSegment.
  uint32_t getOutputSegmentOffset() const;
  uint32_t getOutputSegmentIndex() const;
  uint32_t getSize() const { return Size; }

  InputSegment *Segment = nullptr;

protected:
  uint32_t Offset = 0;
  uint32_t Size = 0;
};

class UndefinedData : public DataSymbol {
public:
  UndefinedData(StringRef Name, uint32_t Flags, InputFile *File = nullptr)
      : DataSymbol(Name, UndefinedDataKind, Flags, File) {}
  static bool classof(const Symbol *S) {
    return S->kind() == UndefinedDataKind;
  }
};

class GlobalSymbol : public Symbol {
public:
  static bool classof(const Symbol *S) {
    return S->kind() == DefinedGlobalKind || S->kind() == UndefinedGlobalKind;
  }

  const WasmGlobalType *getGlobalType() const { return GlobalType; }

  // Get/set the global index
  uint32_t getGlobalIndex() const;
  void setGlobalIndex(uint32_t Index);
  bool hasGlobalIndex() const;

protected:
  GlobalSymbol(StringRef Name, Kind K, uint32_t Flags, InputFile *F,
               const WasmGlobalType *GlobalType)
      : Symbol(Name, K, Flags, F), GlobalType(GlobalType) {}

  // Explicit function type, needed for undefined or synthetic functions only.
  // For regular defined globals this information comes from the InputChunk.
  const WasmGlobalType *GlobalType;
  uint32_t GlobalIndex = INVALID_INDEX;
};

class DefinedGlobal : public GlobalSymbol {
public:
  DefinedGlobal(StringRef Name, uint32_t Flags, InputFile *File,
                InputGlobal *Global);

  static bool classof(const Symbol *S) {
    return S->kind() == DefinedGlobalKind;
  }

  InputGlobal *Global;
};

class UndefinedGlobal : public GlobalSymbol {
public:
  UndefinedGlobal(StringRef Name, uint32_t Flags, InputFile *File = nullptr,
                  const WasmGlobalType *Type = nullptr)
      : GlobalSymbol(Name, UndefinedGlobalKind, Flags, File, Type) {}

  static bool classof(const Symbol *S) {
    return S->kind() == UndefinedGlobalKind;
  }
};

class LazySymbol : public Symbol {
public:
  LazySymbol(StringRef Name, InputFile *File, const Archive::Symbol &Sym)
      : Symbol(Name, LazyKind, 0, File), ArchiveSymbol(Sym) {}

  static bool classof(const Symbol *S) { return S->kind() == LazyKind; }
  void fetch();

private:
  Archive::Symbol ArchiveSymbol;
};

// linker-generated symbols
struct WasmSym {
  // __stack_pointer
  // Global that holds the address of the top of the explicit value stack in
  // linear memory.
  static DefinedGlobal *StackPointer;

  // __data_end
  // Symbol marking the end of the data and bss.
  static DefinedData *DataEnd;

  // __heap_base
  // Symbol marking the end of the data, bss and explicit stack.  Any linear
  // memory following this address is not used by the linked code and can
  // therefore be used as a backing store for brk()/malloc() implementations.
  static DefinedData *HeapBase;

  // __wasm_call_ctors
  // Function that directly calls all ctors in priority order.
  static DefinedFunction *CallCtors;

  // __dso_handle
  // Symbol used in calls to __cxa_atexit to determine current DLL
  static DefinedData *DsoHandle;
};

// A buffer class that is large enough to hold any Symbol-derived
// object. We allocate memory using this class and instantiate a symbol
// using the placement new.
union SymbolUnion {
  alignas(DefinedFunction) char A[sizeof(DefinedFunction)];
  alignas(DefinedData) char B[sizeof(DefinedData)];
  alignas(DefinedGlobal) char C[sizeof(DefinedGlobal)];
  alignas(LazySymbol) char D[sizeof(LazySymbol)];
  alignas(UndefinedFunction) char E[sizeof(UndefinedFunction)];
  alignas(UndefinedData) char F[sizeof(UndefinedData)];
  alignas(UndefinedGlobal) char G[sizeof(UndefinedGlobal)];
  alignas(SectionSymbol) char I[sizeof(SectionSymbol)];
};

template <typename T, typename... ArgT>
T *replaceSymbol(Symbol *S, ArgT &&... Arg) {
  static_assert(std::is_trivially_destructible<T>(),
                "Symbol types must be trivially destructible");
  static_assert(sizeof(T) <= sizeof(SymbolUnion), "Symbol too small");
  static_assert(alignof(T) <= alignof(SymbolUnion),
                "SymbolUnion not aligned enough");
  assert(static_cast<Symbol *>(static_cast<T *>(nullptr)) == nullptr &&
         "Not a Symbol");

  Symbol SymCopy = *S;

  T *S2 = new (S) T(std::forward<ArgT>(Arg)...);
  S2->IsUsedInRegularObj = SymCopy.IsUsedInRegularObj;
  S2->ForceExport = SymCopy.ForceExport;
  return S2;
}

} // namespace wasm

// Returns a symbol name for an error message.
std::string toString(const wasm::Symbol &Sym);
std::string toString(wasm::Symbol::Kind Kind);

} // namespace lld

#endif
