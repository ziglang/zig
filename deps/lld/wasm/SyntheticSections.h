//===- SyntheticSection.h ---------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Synthetic sections represent chunks of linker-created data. If you
// need to create a chunk of data that to be included in some section
// in the result, you probably want to create that as a synthetic section.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_WASM_SYNTHETIC_SECTIONS_H
#define LLD_WASM_SYNTHETIC_SECTIONS_H

#include "OutputSections.h"

#include "llvm/ADT/SmallSet.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/Object/WasmTraits.h"

#define DEBUG_TYPE "lld"

namespace lld {
namespace wasm {

// An init entry to be written to either the synthetic init func or the
// linking metadata.
struct WasmInitEntry {
  const FunctionSymbol *sym;
  uint32_t priority;
};

class SyntheticSection : public OutputSection {
public:
  SyntheticSection(uint32_t type, std::string name = "")
      : OutputSection(type, name), bodyOutputStream(body) {
    if (!name.empty())
      writeStr(bodyOutputStream, name, "section name");
  }

  void writeTo(uint8_t *buf) override {
    assert(offset);
    log("writing " + toString(*this));
    memcpy(buf + offset, header.data(), header.size());
    memcpy(buf + offset + header.size(), body.data(), body.size());
  }

  size_t getSize() const override { return header.size() + body.size(); }

  virtual void writeBody() {}

  void finalizeContents() override {
    writeBody();
    bodyOutputStream.flush();
    createHeader(body.size());
  }

  raw_ostream &getStream() { return bodyOutputStream; }

  std::string body;

protected:
  llvm::raw_string_ostream bodyOutputStream;
};

// Create the custom "dylink" section containing information for the dynamic
// linker.
// See
// https://github.com/WebAssembly/tool-conventions/blob/master/DynamicLinking.md
class DylinkSection : public SyntheticSection {
public:
  DylinkSection() : SyntheticSection(llvm::wasm::WASM_SEC_CUSTOM, "dylink") {}
  bool isNeeded() const override { return config->isPic; }
  void writeBody() override;

  uint32_t memAlign = 0;
  uint32_t memSize = 0;
};

class TypeSection : public SyntheticSection {
public:
  TypeSection() : SyntheticSection(llvm::wasm::WASM_SEC_TYPE) {}

  bool isNeeded() const override { return types.size() > 0; };
  void writeBody() override;
  uint32_t registerType(const WasmSignature &sig);
  uint32_t lookupType(const WasmSignature &sig);

protected:
  std::vector<const WasmSignature *> types;
  llvm::DenseMap<WasmSignature, int32_t> typeIndices;
};

class ImportSection : public SyntheticSection {
public:
  ImportSection() : SyntheticSection(llvm::wasm::WASM_SEC_IMPORT) {}
  bool isNeeded() const override { return getNumImports() > 0; }
  void writeBody() override;
  void addImport(Symbol *sym);
  void addGOTEntry(Symbol *sym);
  void seal() { isSealed = true; }
  uint32_t getNumImports() const;
  uint32_t getNumImportedGlobals() const {
    assert(isSealed);
    return numImportedGlobals;
  }
  uint32_t getNumImportedFunctions() const {
    assert(isSealed);
    return numImportedFunctions;
  }
  uint32_t getNumImportedEvents() const {
    assert(isSealed);
    return numImportedEvents;
  }

  std::vector<const Symbol *> importedSymbols;

protected:
  bool isSealed = false;
  unsigned numImportedGlobals = 0;
  unsigned numImportedFunctions = 0;
  unsigned numImportedEvents = 0;
  std::vector<const Symbol *> gotSymbols;
};

class FunctionSection : public SyntheticSection {
public:
  FunctionSection() : SyntheticSection(llvm::wasm::WASM_SEC_FUNCTION) {}

  bool isNeeded() const override { return inputFunctions.size() > 0; };
  void writeBody() override;
  void addFunction(InputFunction *func);

  std::vector<InputFunction *> inputFunctions;

protected:
};

class MemorySection : public SyntheticSection {
public:
  MemorySection() : SyntheticSection(llvm::wasm::WASM_SEC_MEMORY) {}

  bool isNeeded() const override { return !config->importMemory; }
  void writeBody() override;

  uint32_t numMemoryPages = 0;
  uint32_t maxMemoryPages = 0;
};

class TableSection : public SyntheticSection {
public:
  TableSection() : SyntheticSection(llvm::wasm::WASM_SEC_TABLE) {}

  bool isNeeded() const override {
    // Always output a table section (or table import), even if there are no
    // indirect calls.  There are two reasons for this:
    //  1. For executables it is useful to have an empty table slot at 0
    //     which can be filled with a null function call handler.
    //  2. If we don't do this, any program that contains a call_indirect but
    //     no address-taken function will fail at validation time since it is
    //     a validation error to include a call_indirect instruction if there
    //     is not table.
    return !config->importTable;
  }

  void writeBody() override;
};

class GlobalSection : public SyntheticSection {
public:
  GlobalSection() : SyntheticSection(llvm::wasm::WASM_SEC_GLOBAL) {}
  uint32_t numGlobals() const {
    return inputGlobals.size() + definedFakeGlobals.size();
  }
  bool isNeeded() const override { return numGlobals() > 0; }
  void writeBody() override;
  void addGlobal(InputGlobal *global);

  std::vector<const DefinedData *> definedFakeGlobals;
  std::vector<InputGlobal *> inputGlobals;
};

// The event section contains a list of declared wasm events associated with the
// module. Currently the only supported event kind is exceptions. A single event
// entry represents a single event with an event tag. All C++ exceptions are
// represented by a single event. An event entry in this section contains
// information on what kind of event it is (e.g. exception) and the type of
// values contained in a single event object. (In wasm, an event can contain
// multiple values of primitive types. But for C++ exceptions, we just throw a
// pointer which is an i32 value (for wasm32 architecture), so the signature of
// C++ exception is (i32)->(void), because all event types are assumed to have
// void return type to share WasmSignature with functions.)
class EventSection : public SyntheticSection {
public:
  EventSection() : SyntheticSection(llvm::wasm::WASM_SEC_EVENT) {}
  void writeBody() override;
  bool isNeeded() const override { return inputEvents.size() > 0; }
  void addEvent(InputEvent *event);

  std::vector<InputEvent *> inputEvents;
};

class ExportSection : public SyntheticSection {
public:
  ExportSection() : SyntheticSection(llvm::wasm::WASM_SEC_EXPORT) {}
  bool isNeeded() const override { return exports.size() > 0; }
  void writeBody() override;

  std::vector<llvm::wasm::WasmExport> exports;
};

class ElemSection : public SyntheticSection {
public:
  ElemSection(uint32_t offset)
      : SyntheticSection(llvm::wasm::WASM_SEC_ELEM), elemOffset(offset) {}
  bool isNeeded() const override { return indirectFunctions.size() > 0; };
  void writeBody() override;
  void addEntry(FunctionSymbol *sym);
  uint32_t numEntries() const { return indirectFunctions.size(); }
  uint32_t elemOffset;

protected:
  std::vector<const FunctionSymbol *> indirectFunctions;
};

class DataCountSection : public SyntheticSection {
public:
  DataCountSection(uint32_t numSegments)
      : SyntheticSection(llvm::wasm::WASM_SEC_DATACOUNT),
        numSegments(numSegments) {}
  bool isNeeded() const override;
  void writeBody() override;

protected:
  uint32_t numSegments;
};

// Create the custom "linking" section containing linker metadata.
// This is only created when relocatable output is requested.
class LinkingSection : public SyntheticSection {
public:
  LinkingSection(const std::vector<WasmInitEntry> &initFunctions,
                 const std::vector<OutputSegment *> &dataSegments)
      : SyntheticSection(llvm::wasm::WASM_SEC_CUSTOM, "linking"),
        initFunctions(initFunctions), dataSegments(dataSegments) {}
  bool isNeeded() const override {
    return config->relocatable || config->emitRelocs;
  }
  void writeBody() override;
  void addToSymtab(Symbol *sym);

protected:
  std::vector<const Symbol *> symtabEntries;
  llvm::StringMap<uint32_t> sectionSymbolIndices;
  const std::vector<WasmInitEntry> &initFunctions;
  const std::vector<OutputSegment *> &dataSegments;
};

// Create the custom "name" section containing debug symbol names.
class NameSection : public SyntheticSection {
public:
  NameSection() : SyntheticSection(llvm::wasm::WASM_SEC_CUSTOM, "name") {}
  bool isNeeded() const override {
    return !config->stripDebug && !config->stripAll && numNames() > 0;
  }
  void writeBody() override;
  unsigned numNames() const;
};

class ProducersSection : public SyntheticSection {
public:
  ProducersSection()
      : SyntheticSection(llvm::wasm::WASM_SEC_CUSTOM, "producers") {}
  bool isNeeded() const override {
    return !config->stripAll && fieldCount() > 0;
  }
  void writeBody() override;
  void addInfo(const llvm::wasm::WasmProducerInfo &info);

protected:
  int fieldCount() const {
    return int(!languages.empty()) + int(!tools.empty()) + int(!sDKs.empty());
  }
  SmallVector<std::pair<std::string, std::string>, 8> languages;
  SmallVector<std::pair<std::string, std::string>, 8> tools;
  SmallVector<std::pair<std::string, std::string>, 8> sDKs;
};

class TargetFeaturesSection : public SyntheticSection {
public:
  TargetFeaturesSection()
      : SyntheticSection(llvm::wasm::WASM_SEC_CUSTOM, "target_features") {}
  bool isNeeded() const override {
    return !config->stripAll && features.size() > 0;
  }
  void writeBody() override;

  llvm::SmallSet<std::string, 8> features;
};

class RelocSection : public SyntheticSection {
public:
  RelocSection(StringRef name, OutputSection *sec)
      : SyntheticSection(llvm::wasm::WASM_SEC_CUSTOM, name), sec(sec) {}
  void writeBody() override;
  bool isNeeded() const override { return sec->getNumRelocations() > 0; };

protected:
  OutputSection *sec;
};

// Linker generated output sections
struct OutStruct {
  DylinkSection *dylinkSec;
  TypeSection *typeSec;
  FunctionSection *functionSec;
  ImportSection *importSec;
  TableSection *tableSec;
  MemorySection *memorySec;
  GlobalSection *globalSec;
  EventSection *eventSec;
  ExportSection *exportSec;
  ElemSection *elemSec;
  DataCountSection *dataCountSec;
  LinkingSection *linkingSec;
  NameSection *nameSec;
  ProducersSection *producersSec;
  TargetFeaturesSection *targetFeaturesSec;
};

extern OutStruct out;

} // namespace wasm
} // namespace lld

#endif
