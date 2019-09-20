//===- SyntheticSections.cpp ----------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains linker-synthesized sections.
//
//===----------------------------------------------------------------------===//

#include "SyntheticSections.h"

#include "InputChunks.h"
#include "InputEvent.h"
#include "InputGlobal.h"
#include "OutputSegment.h"
#include "SymbolTable.h"
#include "llvm/Support/Path.h"

using namespace llvm;
using namespace llvm::wasm;

using namespace lld;
using namespace lld::wasm;

OutStruct lld::wasm::out;

namespace {

// Some synthetic sections (e.g. "name" and "linking") have subsections.
// Just like the synthetic sections themselves these need to be created before
// they can be written out (since they are preceded by their length). This
// class is used to create subsections and then write them into the stream
// of the parent section.
class SubSection {
public:
  explicit SubSection(uint32_t type) : type(type) {}

  void writeTo(raw_ostream &to) {
    os.flush();
    writeUleb128(to, type, "subsection type");
    writeUleb128(to, body.size(), "subsection size");
    to.write(body.data(), body.size());
  }

private:
  uint32_t type;
  std::string body;

public:
  raw_string_ostream os{body};
};

} // namespace

void DylinkSection::writeBody() {
  raw_ostream &os = bodyOutputStream;

  writeUleb128(os, memSize, "MemSize");
  writeUleb128(os, memAlign, "MemAlign");
  writeUleb128(os, out.elemSec->numEntries(), "TableSize");
  writeUleb128(os, 0, "TableAlign");
  writeUleb128(os, symtab->sharedFiles.size(), "Needed");
  for (auto *so : symtab->sharedFiles)
    writeStr(os, llvm::sys::path::filename(so->getName()), "so name");
}

uint32_t TypeSection::registerType(const WasmSignature &sig) {
  auto pair = typeIndices.insert(std::make_pair(sig, types.size()));
  if (pair.second) {
    LLVM_DEBUG(llvm::dbgs() << "type " << toString(sig) << "\n");
    types.push_back(&sig);
  }
  return pair.first->second;
}

uint32_t TypeSection::lookupType(const WasmSignature &sig) {
  auto it = typeIndices.find(sig);
  if (it == typeIndices.end()) {
    error("type not found: " + toString(sig));
    return 0;
  }
  return it->second;
}

void TypeSection::writeBody() {
  writeUleb128(bodyOutputStream, types.size(), "type count");
  for (const WasmSignature *sig : types)
    writeSig(bodyOutputStream, *sig);
}

uint32_t ImportSection::getNumImports() const {
  assert(isSealed);
  uint32_t numImports = importedSymbols.size() + gotSymbols.size();
  if (config->importMemory)
    ++numImports;
  if (config->importTable)
    ++numImports;
  return numImports;
}

void ImportSection::addGOTEntry(Symbol *sym) {
  assert(!isSealed);
  if (sym->hasGOTIndex())
    return;
  sym->setGOTIndex(numImportedGlobals++);
  gotSymbols.push_back(sym);
}

void ImportSection::addImport(Symbol *sym) {
  assert(!isSealed);
  importedSymbols.emplace_back(sym);
  if (auto *f = dyn_cast<FunctionSymbol>(sym))
    f->setFunctionIndex(numImportedFunctions++);
  else if (auto *g = dyn_cast<GlobalSymbol>(sym))
    g->setGlobalIndex(numImportedGlobals++);
  else
    cast<EventSymbol>(sym)->setEventIndex(numImportedEvents++);
}

void ImportSection::writeBody() {
  raw_ostream &os = bodyOutputStream;

  writeUleb128(os, getNumImports(), "import count");

  if (config->importMemory) {
    WasmImport import;
    import.Module = defaultModule;
    import.Field = "memory";
    import.Kind = WASM_EXTERNAL_MEMORY;
    import.Memory.Flags = 0;
    import.Memory.Initial = out.memorySec->numMemoryPages;
    if (out.memorySec->maxMemoryPages != 0 || config->sharedMemory) {
      import.Memory.Flags |= WASM_LIMITS_FLAG_HAS_MAX;
      import.Memory.Maximum = out.memorySec->maxMemoryPages;
    }
    if (config->sharedMemory)
      import.Memory.Flags |= WASM_LIMITS_FLAG_IS_SHARED;
    writeImport(os, import);
  }

  if (config->importTable) {
    uint32_t tableSize = out.elemSec->elemOffset + out.elemSec->numEntries();
    WasmImport import;
    import.Module = defaultModule;
    import.Field = functionTableName;
    import.Kind = WASM_EXTERNAL_TABLE;
    import.Table.ElemType = WASM_TYPE_FUNCREF;
    import.Table.Limits = {0, tableSize, 0};
    writeImport(os, import);
  }

  for (const Symbol *sym : importedSymbols) {
    WasmImport import;
    if (auto *f = dyn_cast<UndefinedFunction>(sym)) {
      import.Field = f->importName;
      import.Module = f->importModule;
    } else if (auto *g = dyn_cast<UndefinedGlobal>(sym)) {
      import.Field = g->importName;
      import.Module = g->importModule;
    } else {
      import.Field = sym->getName();
      import.Module = defaultModule;
    }

    if (auto *functionSym = dyn_cast<FunctionSymbol>(sym)) {
      import.Kind = WASM_EXTERNAL_FUNCTION;
      import.SigIndex = out.typeSec->lookupType(*functionSym->signature);
    } else if (auto *globalSym = dyn_cast<GlobalSymbol>(sym)) {
      import.Kind = WASM_EXTERNAL_GLOBAL;
      import.Global = *globalSym->getGlobalType();
    } else {
      auto *eventSym = cast<EventSymbol>(sym);
      import.Kind = WASM_EXTERNAL_EVENT;
      import.Event.Attribute = eventSym->getEventType()->Attribute;
      import.Event.SigIndex = out.typeSec->lookupType(*eventSym->signature);
    }
    writeImport(os, import);
  }

  for (const Symbol *sym : gotSymbols) {
    WasmImport import;
    import.Kind = WASM_EXTERNAL_GLOBAL;
    import.Global = {WASM_TYPE_I32, true};
    if (isa<DataSymbol>(sym))
      import.Module = "GOT.mem";
    else
      import.Module = "GOT.func";
    import.Field = sym->getName();
    writeImport(os, import);
  }
}

void FunctionSection::writeBody() {
  raw_ostream &os = bodyOutputStream;

  writeUleb128(os, inputFunctions.size(), "function count");
  for (const InputFunction *func : inputFunctions)
    writeUleb128(os, out.typeSec->lookupType(func->signature), "sig index");
}

void FunctionSection::addFunction(InputFunction *func) {
  if (!func->live)
    return;
  uint32_t functionIndex =
      out.importSec->getNumImportedFunctions() + inputFunctions.size();
  inputFunctions.emplace_back(func);
  func->setFunctionIndex(functionIndex);
}

void TableSection::writeBody() {
  uint32_t tableSize = out.elemSec->elemOffset + out.elemSec->numEntries();

  raw_ostream &os = bodyOutputStream;
  writeUleb128(os, 1, "table count");
  WasmLimits limits = {WASM_LIMITS_FLAG_HAS_MAX, tableSize, tableSize};
  writeTableType(os, WasmTable{WASM_TYPE_FUNCREF, limits});
}

void MemorySection::writeBody() {
  raw_ostream &os = bodyOutputStream;

  bool hasMax = maxMemoryPages != 0 || config->sharedMemory;
  writeUleb128(os, 1, "memory count");
  unsigned flags = 0;
  if (hasMax)
    flags |= WASM_LIMITS_FLAG_HAS_MAX;
  if (config->sharedMemory)
    flags |= WASM_LIMITS_FLAG_IS_SHARED;
  writeUleb128(os, flags, "memory limits flags");
  writeUleb128(os, numMemoryPages, "initial pages");
  if (hasMax)
    writeUleb128(os, maxMemoryPages, "max pages");
}

void GlobalSection::writeBody() {
  raw_ostream &os = bodyOutputStream;

  writeUleb128(os, numGlobals(), "global count");
  for (const InputGlobal *g : inputGlobals)
    writeGlobal(os, g->global);
  for (const DefinedData *sym : definedFakeGlobals) {
    WasmGlobal global;
    global.Type = {WASM_TYPE_I32, false};
    global.InitExpr.Opcode = WASM_OPCODE_I32_CONST;
    global.InitExpr.Value.Int32 = sym->getVirtualAddress();
    writeGlobal(os, global);
  }
}

void GlobalSection::addGlobal(InputGlobal *global) {
  if (!global->live)
    return;
  uint32_t globalIndex =
      out.importSec->getNumImportedGlobals() + inputGlobals.size();
  LLVM_DEBUG(dbgs() << "addGlobal: " << globalIndex << "\n");
  global->setGlobalIndex(globalIndex);
  out.globalSec->inputGlobals.push_back(global);
}

void EventSection::writeBody() {
  raw_ostream &os = bodyOutputStream;

  writeUleb128(os, inputEvents.size(), "event count");
  for (InputEvent *e : inputEvents) {
    e->event.Type.SigIndex = out.typeSec->lookupType(e->signature);
    writeEvent(os, e->event);
  }
}

void EventSection::addEvent(InputEvent *event) {
  if (!event->live)
    return;
  uint32_t eventIndex =
      out.importSec->getNumImportedEvents() + inputEvents.size();
  LLVM_DEBUG(dbgs() << "addEvent: " << eventIndex << "\n");
  event->setEventIndex(eventIndex);
  inputEvents.push_back(event);
}

void ExportSection::writeBody() {
  raw_ostream &os = bodyOutputStream;

  writeUleb128(os, exports.size(), "export count");
  for (const WasmExport &export_ : exports)
    writeExport(os, export_);
}

void ElemSection::addEntry(FunctionSymbol *sym) {
  if (sym->hasTableIndex())
    return;
  sym->setTableIndex(elemOffset + indirectFunctions.size());
  indirectFunctions.emplace_back(sym);
}

void ElemSection::writeBody() {
  raw_ostream &os = bodyOutputStream;

  writeUleb128(os, 1, "segment count");
  writeUleb128(os, 0, "table index");
  WasmInitExpr initExpr;
  if (config->isPic) {
    initExpr.Opcode = WASM_OPCODE_GLOBAL_GET;
    initExpr.Value.Global = WasmSym::tableBase->getGlobalIndex();
  } else {
    initExpr.Opcode = WASM_OPCODE_I32_CONST;
    initExpr.Value.Int32 = elemOffset;
  }
  writeInitExpr(os, initExpr);
  writeUleb128(os, indirectFunctions.size(), "elem count");

  uint32_t tableIndex = elemOffset;
  for (const FunctionSymbol *sym : indirectFunctions) {
    assert(sym->getTableIndex() == tableIndex);
    writeUleb128(os, sym->getFunctionIndex(), "function index");
    ++tableIndex;
  }
}

void DataCountSection::writeBody() {
  writeUleb128(bodyOutputStream, numSegments, "data count");
}

bool DataCountSection::isNeeded() const {
  return numSegments && config->passiveSegments;
}

static uint32_t getWasmFlags(const Symbol *sym) {
  uint32_t flags = 0;
  if (sym->isLocal())
    flags |= WASM_SYMBOL_BINDING_LOCAL;
  if (sym->isWeak())
    flags |= WASM_SYMBOL_BINDING_WEAK;
  if (sym->isHidden())
    flags |= WASM_SYMBOL_VISIBILITY_HIDDEN;
  if (sym->isUndefined())
    flags |= WASM_SYMBOL_UNDEFINED;
  if (auto *f = dyn_cast<UndefinedFunction>(sym)) {
    if (f->getName() != f->importName)
      flags |= WASM_SYMBOL_EXPLICIT_NAME;
  } else if (auto *g = dyn_cast<UndefinedGlobal>(sym)) {
    if (g->getName() != g->importName)
      flags |= WASM_SYMBOL_EXPLICIT_NAME;
  }
  return flags;
}

void LinkingSection::writeBody() {
  raw_ostream &os = bodyOutputStream;

  writeUleb128(os, WasmMetadataVersion, "Version");

  if (!symtabEntries.empty()) {
    SubSection sub(WASM_SYMBOL_TABLE);
    writeUleb128(sub.os, symtabEntries.size(), "num symbols");

    for (const Symbol *sym : symtabEntries) {
      assert(sym->isDefined() || sym->isUndefined());
      WasmSymbolType kind = sym->getWasmType();
      uint32_t flags = getWasmFlags(sym);

      writeU8(sub.os, kind, "sym kind");
      writeUleb128(sub.os, flags, "sym flags");

      if (auto *f = dyn_cast<FunctionSymbol>(sym)) {
        writeUleb128(sub.os, f->getFunctionIndex(), "index");
        if (sym->isDefined() || (flags & WASM_SYMBOL_EXPLICIT_NAME) != 0)
          writeStr(sub.os, sym->getName(), "sym name");
      } else if (auto *g = dyn_cast<GlobalSymbol>(sym)) {
        writeUleb128(sub.os, g->getGlobalIndex(), "index");
        if (sym->isDefined() || (flags & WASM_SYMBOL_EXPLICIT_NAME) != 0)
          writeStr(sub.os, sym->getName(), "sym name");
      } else if (auto *e = dyn_cast<EventSymbol>(sym)) {
        writeUleb128(sub.os, e->getEventIndex(), "index");
        if (sym->isDefined() || (flags & WASM_SYMBOL_EXPLICIT_NAME) != 0)
          writeStr(sub.os, sym->getName(), "sym name");
      } else if (isa<DataSymbol>(sym)) {
        writeStr(sub.os, sym->getName(), "sym name");
        if (auto *dataSym = dyn_cast<DefinedData>(sym)) {
          writeUleb128(sub.os, dataSym->getOutputSegmentIndex(), "index");
          writeUleb128(sub.os, dataSym->getOutputSegmentOffset(),
                       "data offset");
          writeUleb128(sub.os, dataSym->getSize(), "data size");
        }
      } else {
        auto *s = cast<OutputSectionSymbol>(sym);
        writeUleb128(sub.os, s->section->sectionIndex, "sym section index");
      }
    }

    sub.writeTo(os);
  }

  if (dataSegments.size()) {
    SubSection sub(WASM_SEGMENT_INFO);
    writeUleb128(sub.os, dataSegments.size(), "num data segments");
    for (const OutputSegment *s : dataSegments) {
      writeStr(sub.os, s->name, "segment name");
      writeUleb128(sub.os, s->alignment, "alignment");
      writeUleb128(sub.os, 0, "flags");
    }
    sub.writeTo(os);
  }

  if (!initFunctions.empty()) {
    SubSection sub(WASM_INIT_FUNCS);
    writeUleb128(sub.os, initFunctions.size(), "num init functions");
    for (const WasmInitEntry &f : initFunctions) {
      writeUleb128(sub.os, f.priority, "priority");
      writeUleb128(sub.os, f.sym->getOutputSymbolIndex(), "function index");
    }
    sub.writeTo(os);
  }

  struct ComdatEntry {
    unsigned kind;
    uint32_t index;
  };
  std::map<StringRef, std::vector<ComdatEntry>> comdats;

  for (const InputFunction *f : out.functionSec->inputFunctions) {
    StringRef comdat = f->getComdatName();
    if (!comdat.empty())
      comdats[comdat].emplace_back(
          ComdatEntry{WASM_COMDAT_FUNCTION, f->getFunctionIndex()});
  }
  for (uint32_t i = 0; i < dataSegments.size(); ++i) {
    const auto &inputSegments = dataSegments[i]->inputSegments;
    if (inputSegments.empty())
      continue;
    StringRef comdat = inputSegments[0]->getComdatName();
#ifndef NDEBUG
    for (const InputSegment *isec : inputSegments)
      assert(isec->getComdatName() == comdat);
#endif
    if (!comdat.empty())
      comdats[comdat].emplace_back(ComdatEntry{WASM_COMDAT_DATA, i});
  }

  if (!comdats.empty()) {
    SubSection sub(WASM_COMDAT_INFO);
    writeUleb128(sub.os, comdats.size(), "num comdats");
    for (const auto &c : comdats) {
      writeStr(sub.os, c.first, "comdat name");
      writeUleb128(sub.os, 0, "comdat flags"); // flags for future use
      writeUleb128(sub.os, c.second.size(), "num entries");
      for (const ComdatEntry &entry : c.second) {
        writeU8(sub.os, entry.kind, "entry kind");
        writeUleb128(sub.os, entry.index, "entry index");
      }
    }
    sub.writeTo(os);
  }
}

void LinkingSection::addToSymtab(Symbol *sym) {
  sym->setOutputSymbolIndex(symtabEntries.size());
  symtabEntries.emplace_back(sym);
}

unsigned NameSection::numNames() const {
  unsigned numNames = out.importSec->getNumImportedFunctions();
  for (const InputFunction *f : out.functionSec->inputFunctions)
    if (!f->getName().empty() || !f->getDebugName().empty())
      ++numNames;

  return numNames;
}

// Create the custom "name" section containing debug symbol names.
void NameSection::writeBody() {
  SubSection sub(WASM_NAMES_FUNCTION);
  writeUleb128(sub.os, numNames(), "name count");

  // Names must appear in function index order.  As it happens importedSymbols
  // and inputFunctions are numbered in order with imported functions coming
  // first.
  for (const Symbol *s : out.importSec->importedSymbols) {
    if (auto *f = dyn_cast<FunctionSymbol>(s)) {
      writeUleb128(sub.os, f->getFunctionIndex(), "func index");
      writeStr(sub.os, toString(*s), "symbol name");
    }
  }
  for (const InputFunction *f : out.functionSec->inputFunctions) {
    if (!f->getName().empty()) {
      writeUleb128(sub.os, f->getFunctionIndex(), "func index");
      if (!f->getDebugName().empty()) {
        writeStr(sub.os, f->getDebugName(), "symbol name");
      } else {
        writeStr(sub.os, maybeDemangleSymbol(f->getName()), "symbol name");
      }
    }
  }

  sub.writeTo(bodyOutputStream);
}

void ProducersSection::addInfo(const WasmProducerInfo &info) {
  for (auto &producers :
       {std::make_pair(&info.Languages, &languages),
        std::make_pair(&info.Tools, &tools), std::make_pair(&info.SDKs, &sDKs)})
    for (auto &producer : *producers.first)
      if (producers.second->end() ==
          llvm::find_if(*producers.second,
                        [&](std::pair<std::string, std::string> seen) {
                          return seen.first == producer.first;
                        }))
        producers.second->push_back(producer);
}

void ProducersSection::writeBody() {
  auto &os = bodyOutputStream;
  writeUleb128(os, fieldCount(), "field count");
  for (auto &field :
       {std::make_pair("language", languages),
        std::make_pair("processed-by", tools), std::make_pair("sdk", sDKs)}) {
    if (field.second.empty())
      continue;
    writeStr(os, field.first, "field name");
    writeUleb128(os, field.second.size(), "number of entries");
    for (auto &entry : field.second) {
      writeStr(os, entry.first, "producer name");
      writeStr(os, entry.second, "producer version");
    }
  }
}

void TargetFeaturesSection::writeBody() {
  SmallVector<std::string, 8> emitted(features.begin(), features.end());
  llvm::sort(emitted);
  auto &os = bodyOutputStream;
  writeUleb128(os, emitted.size(), "feature count");
  for (auto &feature : emitted) {
    writeU8(os, WASM_FEATURE_PREFIX_USED, "feature used prefix");
    writeStr(os, feature, "feature name");
  }
}

void RelocSection::writeBody() {
  uint32_t count = sec->getNumRelocations();
  assert(sec->sectionIndex != UINT32_MAX);
  writeUleb128(bodyOutputStream, sec->sectionIndex, "reloc section");
  writeUleb128(bodyOutputStream, count, "reloc count");
  sec->writeRelocations(bodyOutputStream);
}
