//===- Symbols.h ------------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_WASM_SYMBOLS_H
#define LLD_WASM_SYMBOLS_H

#include "Config.h"
#include "lld/Common/LLVM.h"
#include "llvm/Object/Archive.h"
#include "llvm/Object/Wasm.h"

namespace lld {
namespace wasm {

// Shared string constants

// The default module name to use for symbol imports.
extern const char *defaultModule;

// The name under which to import or export the wasm table.
extern const char *functionTableName;

using llvm::wasm::WasmSymbolType;

class InputFile;
class InputChunk;
class InputSegment;
class InputFunction;
class InputGlobal;
class InputEvent;
class InputSection;
class OutputSection;

#define INVALID_INDEX UINT32_MAX

// The base class for real symbol classes.
class Symbol {
public:
  enum Kind : uint8_t {
    DefinedFunctionKind,
    DefinedDataKind,
    DefinedGlobalKind,
    DefinedEventKind,
    SectionKind,
    OutputSectionKind,
    UndefinedFunctionKind,
    UndefinedDataKind,
    UndefinedGlobalKind,
    LazyKind,
  };

  Kind kind() const { return symbolKind; }

  bool isDefined() const { return !isLazy() && !isUndefined(); }

  bool isUndefined() const {
    return symbolKind == UndefinedFunctionKind ||
           symbolKind == UndefinedDataKind || symbolKind == UndefinedGlobalKind;
  }

  bool isLazy() const { return symbolKind == LazyKind; }

  bool isLocal() const;
  bool isWeak() const;
  bool isHidden() const;

  // Returns true if this symbol exists in a discarded (due to COMDAT) section
  bool isDiscarded() const;

  // True if this is an undefined weak symbol. This only works once
  // all input files have been added.
  bool isUndefWeak() const {
    // See comment on lazy symbols for details.
    return isWeak() && (isUndefined() || isLazy());
  }

  // Returns the symbol name.
  StringRef getName() const { return name; }

  // Returns the file from which this symbol was created.
  InputFile *getFile() const { return file; }

  uint32_t getFlags() const { return flags; }

  InputChunk *getChunk() const;

  // Indicates that the section or import for this symbol will be included in
  // the final image.
  bool isLive() const;

  // Marks the symbol's InputChunk as Live, so that it will be included in the
  // final image.
  void markLive();

  void setHidden(bool isHidden);

  // Get/set the index in the output symbol table.  This is only used for
  // relocatable output.
  uint32_t getOutputSymbolIndex() const;
  void setOutputSymbolIndex(uint32_t index);

  WasmSymbolType getWasmType() const;
  bool isExported() const;

  const WasmSignature* getSignature() const;

  bool isInGOT() const { return gotIndex != INVALID_INDEX; }

  uint32_t getGOTIndex() const {
    assert(gotIndex != INVALID_INDEX);
    return gotIndex;
  }

  void setGOTIndex(uint32_t index);
  bool hasGOTIndex() const { return gotIndex != INVALID_INDEX; }

protected:
  Symbol(StringRef name, Kind k, uint32_t flags, InputFile *f)
      : name(name), file(f), flags(flags), symbolKind(k),
        referenced(!config->gcSections), isUsedInRegularObj(false),
        forceExport(false), canInline(false), traced(false) {}

  StringRef name;
  InputFile *file;
  uint32_t flags;
  uint32_t outputSymbolIndex = INVALID_INDEX;
  uint32_t gotIndex = INVALID_INDEX;
  Kind symbolKind;

public:
  bool referenced : 1;

  // True if the symbol was used for linking and thus need to be added to the
  // output file's symbol table. This is true for all symbols except for
  // unreferenced DSO symbols, lazy (archive) symbols, and bitcode symbols that
  // are unreferenced except by other bitcode objects.
  bool isUsedInRegularObj : 1;

  // True if ths symbol is explicity marked for export (i.e. via the -e/--export
  // command line flag)
  bool forceExport : 1;

  // False if LTO shouldn't inline whatever this symbol points to. If a symbol
  // is overwritten after LTO, LTO shouldn't inline the symbol because it
  // doesn't know the final contents of the symbol.
  bool canInline : 1;

  // True if this symbol is specified by --trace-symbol option.
  bool traced : 1;
};

class FunctionSymbol : public Symbol {
public:
  static bool classof(const Symbol *s) {
    return s->kind() == DefinedFunctionKind ||
           s->kind() == UndefinedFunctionKind;
  }

  // Get/set the table index
  void setTableIndex(uint32_t index);
  uint32_t getTableIndex() const;
  bool hasTableIndex() const;

  // Get/set the function index
  uint32_t getFunctionIndex() const;
  void setFunctionIndex(uint32_t index);
  bool hasFunctionIndex() const;

  const WasmSignature *signature;

protected:
  FunctionSymbol(StringRef name, Kind k, uint32_t flags, InputFile *f,
                 const WasmSignature *sig)
      : Symbol(name, k, flags, f), signature(sig) {}

  uint32_t tableIndex = INVALID_INDEX;
  uint32_t functionIndex = INVALID_INDEX;
};

class DefinedFunction : public FunctionSymbol {
public:
  DefinedFunction(StringRef name, uint32_t flags, InputFile *f,
                  InputFunction *function);

  static bool classof(const Symbol *s) {
    return s->kind() == DefinedFunctionKind;
  }

  InputFunction *function;
};

class UndefinedFunction : public FunctionSymbol {
public:
  UndefinedFunction(StringRef name, StringRef importName,
                    StringRef importModule, uint32_t flags,
                    InputFile *file = nullptr,
                    const WasmSignature *type = nullptr,
                    bool isCalledDirectly = true)
      : FunctionSymbol(name, UndefinedFunctionKind, flags, file, type),
        importName(importName), importModule(importModule), isCalledDirectly(isCalledDirectly) {}

  static bool classof(const Symbol *s) {
    return s->kind() == UndefinedFunctionKind;
  }

  StringRef importName;
  StringRef importModule;
  bool isCalledDirectly;
};

// Section symbols for output sections are different from those for input
// section.  These are generated by the linker and point the OutputSection
// rather than an InputSection.
class OutputSectionSymbol : public Symbol {
public:
  OutputSectionSymbol(const OutputSection *s)
      : Symbol("", OutputSectionKind, llvm::wasm::WASM_SYMBOL_BINDING_LOCAL,
               nullptr),
        section(s) {}

  static bool classof(const Symbol *s) {
    return s->kind() == OutputSectionKind;
  }

  const OutputSection *section;
};

class SectionSymbol : public Symbol {
public:
  SectionSymbol(uint32_t flags, const InputSection *s, InputFile *f = nullptr)
      : Symbol("", SectionKind, flags, f), section(s) {}

  static bool classof(const Symbol *s) { return s->kind() == SectionKind; }

  const OutputSectionSymbol *getOutputSectionSymbol() const;

  const InputSection *section;
};

class DataSymbol : public Symbol {
public:
  static bool classof(const Symbol *s) {
    return s->kind() == DefinedDataKind || s->kind() == UndefinedDataKind;
  }

protected:
  DataSymbol(StringRef name, Kind k, uint32_t flags, InputFile *f)
      : Symbol(name, k, flags, f) {}
};

class DefinedData : public DataSymbol {
public:
  // Constructor for regular data symbols originating from input files.
  DefinedData(StringRef name, uint32_t flags, InputFile *f,
              InputSegment *segment, uint32_t offset, uint32_t size)
      : DataSymbol(name, DefinedDataKind, flags, f), segment(segment),
        offset(offset), size(size) {}

  // Constructor for linker synthetic data symbols.
  DefinedData(StringRef name, uint32_t flags)
      : DataSymbol(name, DefinedDataKind, flags, nullptr) {}

  static bool classof(const Symbol *s) { return s->kind() == DefinedDataKind; }

  // Returns the output virtual address of a defined data symbol.
  uint32_t getVirtualAddress() const;
  void setVirtualAddress(uint32_t va);

  // Returns the offset of a defined data symbol within its OutputSegment.
  uint32_t getOutputSegmentOffset() const;
  uint32_t getOutputSegmentIndex() const;
  uint32_t getSize() const { return size; }

  InputSegment *segment = nullptr;

protected:
  uint32_t offset = 0;
  uint32_t size = 0;
};

class UndefinedData : public DataSymbol {
public:
  UndefinedData(StringRef name, uint32_t flags, InputFile *file = nullptr)
      : DataSymbol(name, UndefinedDataKind, flags, file) {}
  static bool classof(const Symbol *s) {
    return s->kind() == UndefinedDataKind;
  }
};

class GlobalSymbol : public Symbol {
public:
  static bool classof(const Symbol *s) {
    return s->kind() == DefinedGlobalKind || s->kind() == UndefinedGlobalKind;
  }

  const WasmGlobalType *getGlobalType() const { return globalType; }

  // Get/set the global index
  uint32_t getGlobalIndex() const;
  void setGlobalIndex(uint32_t index);
  bool hasGlobalIndex() const;

protected:
  GlobalSymbol(StringRef name, Kind k, uint32_t flags, InputFile *f,
               const WasmGlobalType *globalType)
      : Symbol(name, k, flags, f), globalType(globalType) {}

  const WasmGlobalType *globalType;
  uint32_t globalIndex = INVALID_INDEX;
};

class DefinedGlobal : public GlobalSymbol {
public:
  DefinedGlobal(StringRef name, uint32_t flags, InputFile *file,
                InputGlobal *global);

  static bool classof(const Symbol *s) {
    return s->kind() == DefinedGlobalKind;
  }

  InputGlobal *global;
};

class UndefinedGlobal : public GlobalSymbol {
public:
  UndefinedGlobal(StringRef name, StringRef importName, StringRef importModule,
                  uint32_t flags, InputFile *file = nullptr,
                  const WasmGlobalType *type = nullptr)
      : GlobalSymbol(name, UndefinedGlobalKind, flags, file, type),
        importName(importName), importModule(importModule) {}

  static bool classof(const Symbol *s) {
    return s->kind() == UndefinedGlobalKind;
  }

  StringRef importName;
  StringRef importModule;
};

// Wasm events are features that suspend the current execution and transfer the
// control flow to a corresponding handler. Currently the only supported event
// kind is exceptions.
//
// Event tags are values to distinguish different events. For exceptions, they
// can be used to distinguish different language's exceptions, i.e., all C++
// exceptions have the same tag. Wasm can generate code capable of doing
// different handling actions based on the tag of caught exceptions.
//
// A single EventSymbol object represents a single tag. C++ exception event
// symbol is a weak symbol generated in every object file in which exceptions
// are used, and has name '__cpp_exception' for linking.
class EventSymbol : public Symbol {
public:
  static bool classof(const Symbol *s) { return s->kind() == DefinedEventKind; }

  const WasmEventType *getEventType() const { return eventType; }

  // Get/set the event index
  uint32_t getEventIndex() const;
  void setEventIndex(uint32_t index);
  bool hasEventIndex() const;

  const WasmSignature *signature;

protected:
  EventSymbol(StringRef name, Kind k, uint32_t flags, InputFile *f,
              const WasmEventType *eventType, const WasmSignature *sig)
      : Symbol(name, k, flags, f), signature(sig), eventType(eventType) {}

  const WasmEventType *eventType;
  uint32_t eventIndex = INVALID_INDEX;
};

class DefinedEvent : public EventSymbol {
public:
  DefinedEvent(StringRef name, uint32_t flags, InputFile *file,
               InputEvent *event);

  static bool classof(const Symbol *s) { return s->kind() == DefinedEventKind; }

  InputEvent *event;
};

// LazySymbol represents a symbol that is not yet in the link, but we know where
// to find it if needed. If the resolver finds both Undefined and Lazy for the
// same name, it will ask the Lazy to load a file.
//
// A special complication is the handling of weak undefined symbols. They should
// not load a file, but we have to remember we have seen both the weak undefined
// and the lazy. We represent that with a lazy symbol with a weak binding. This
// means that code looking for undefined symbols normally also has to take lazy
// symbols into consideration.
class LazySymbol : public Symbol {
public:
  LazySymbol(StringRef name, uint32_t flags, InputFile *file,
             const llvm::object::Archive::Symbol &sym)
      : Symbol(name, LazyKind, flags, file), archiveSymbol(sym) {}

  static bool classof(const Symbol *s) { return s->kind() == LazyKind; }
  void fetch();

  // Lazy symbols can have a signature because they can replace an
  // UndefinedFunction which which case we need to be able to preserve the
  // signture.
  // TODO(sbc): This repetition of the signature field is inelegant.  Revisit
  // the use of class hierarchy to represent symbol taxonomy.
  const WasmSignature *signature = nullptr;

private:
  llvm::object::Archive::Symbol archiveSymbol;
};

// linker-generated symbols
struct WasmSym {
  // __global_base
  // Symbol marking the start of the global section.
  static DefinedData *globalBase;

  // __stack_pointer
  // Global that holds the address of the top of the explicit value stack in
  // linear memory.
  static GlobalSymbol *stackPointer;

  // __tls_base
  // Global that holds the address of the base of the current thread's
  // TLS block.
  static GlobalSymbol *tlsBase;

  // __tls_size
  // Symbol whose value is the size of the TLS block.
  static GlobalSymbol *tlsSize;

  // __data_end
  // Symbol marking the end of the data and bss.
  static DefinedData *dataEnd;

  // __heap_base
  // Symbol marking the end of the data, bss and explicit stack.  Any linear
  // memory following this address is not used by the linked code and can
  // therefore be used as a backing store for brk()/malloc() implementations.
  static DefinedData *heapBase;

  // __wasm_call_ctors
  // Function that directly calls all ctors in priority order.
  static DefinedFunction *callCtors;

  // __wasm_init_memory
  // Function that initializes passive data segments post-instantiation.
  static DefinedFunction *initMemory;

  // __wasm_apply_relocs
  // Function that applies relocations to data segment post-instantiation.
  static DefinedFunction *applyRelocs;

  // __wasm_init_tls
  // Function that allocates thread-local storage and initializes it.
  static DefinedFunction *initTLS;

  // __dso_handle
  // Symbol used in calls to __cxa_atexit to determine current DLL
  static DefinedData *dsoHandle;

  // __table_base
  // Used in PIC code for offset of indirect function table
  static UndefinedGlobal *tableBase;

  // __memory_base
  // Used in PIC code for offset of global data
  static UndefinedGlobal *memoryBase;
};

// A buffer class that is large enough to hold any Symbol-derived
// object. We allocate memory using this class and instantiate a symbol
// using the placement new.
union SymbolUnion {
  alignas(DefinedFunction) char a[sizeof(DefinedFunction)];
  alignas(DefinedData) char b[sizeof(DefinedData)];
  alignas(DefinedGlobal) char c[sizeof(DefinedGlobal)];
  alignas(DefinedEvent) char d[sizeof(DefinedEvent)];
  alignas(LazySymbol) char e[sizeof(LazySymbol)];
  alignas(UndefinedFunction) char f[sizeof(UndefinedFunction)];
  alignas(UndefinedData) char g[sizeof(UndefinedData)];
  alignas(UndefinedGlobal) char h[sizeof(UndefinedGlobal)];
  alignas(SectionSymbol) char i[sizeof(SectionSymbol)];
};

// It is important to keep the size of SymbolUnion small for performance and
// memory usage reasons. 96 bytes is a soft limit based on the size of
// UndefinedFunction on a 64-bit system.
static_assert(sizeof(SymbolUnion) <= 96, "SymbolUnion too large");

void printTraceSymbol(Symbol *sym);
void printTraceSymbolUndefined(StringRef name, const InputFile* file);

template <typename T, typename... ArgT>
T *replaceSymbol(Symbol *s, ArgT &&... arg) {
  static_assert(std::is_trivially_destructible<T>(),
                "Symbol types must be trivially destructible");
  static_assert(sizeof(T) <= sizeof(SymbolUnion), "SymbolUnion too small");
  static_assert(alignof(T) <= alignof(SymbolUnion),
                "SymbolUnion not aligned enough");
  assert(static_cast<Symbol *>(static_cast<T *>(nullptr)) == nullptr &&
         "Not a Symbol");

  Symbol symCopy = *s;

  T *s2 = new (s) T(std::forward<ArgT>(arg)...);
  s2->isUsedInRegularObj = symCopy.isUsedInRegularObj;
  s2->forceExport = symCopy.forceExport;
  s2->canInline = symCopy.canInline;
  s2->traced = symCopy.traced;

  // Print out a log message if --trace-symbol was specified.
  // This is for debugging.
  if (s2->traced)
    printTraceSymbol(s2);

  return s2;
}

} // namespace wasm

// Returns a symbol name for an error message.
std::string toString(const wasm::Symbol &sym);
std::string toString(wasm::Symbol::Kind kind);
std::string maybeDemangleSymbol(StringRef name);

} // namespace lld

#endif
