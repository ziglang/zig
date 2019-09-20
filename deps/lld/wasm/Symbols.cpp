//===- Symbols.cpp --------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "Symbols.h"
#include "Config.h"
#include "InputChunks.h"
#include "InputEvent.h"
#include "InputFiles.h"
#include "InputGlobal.h"
#include "OutputSections.h"
#include "OutputSegment.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Strings.h"

#define DEBUG_TYPE "lld"

using namespace llvm;
using namespace llvm::wasm;
using namespace lld;
using namespace lld::wasm;

DefinedFunction *WasmSym::callCtors;
DefinedFunction *WasmSym::initMemory;
DefinedFunction *WasmSym::applyRelocs;
DefinedFunction *WasmSym::initTLS;
DefinedData *WasmSym::dsoHandle;
DefinedData *WasmSym::dataEnd;
DefinedData *WasmSym::globalBase;
DefinedData *WasmSym::heapBase;
GlobalSymbol *WasmSym::stackPointer;
GlobalSymbol *WasmSym::tlsBase;
GlobalSymbol *WasmSym::tlsSize;
UndefinedGlobal *WasmSym::tableBase;
UndefinedGlobal *WasmSym::memoryBase;

WasmSymbolType Symbol::getWasmType() const {
  if (isa<FunctionSymbol>(this))
    return WASM_SYMBOL_TYPE_FUNCTION;
  if (isa<DataSymbol>(this))
    return WASM_SYMBOL_TYPE_DATA;
  if (isa<GlobalSymbol>(this))
    return WASM_SYMBOL_TYPE_GLOBAL;
  if (isa<EventSymbol>(this))
    return WASM_SYMBOL_TYPE_EVENT;
  if (isa<SectionSymbol>(this) || isa<OutputSectionSymbol>(this))
    return WASM_SYMBOL_TYPE_SECTION;
  llvm_unreachable("invalid symbol kind");
}

const WasmSignature *Symbol::getSignature() const {
  if (auto* f = dyn_cast<FunctionSymbol>(this))
    return f->signature;
  if (auto *l = dyn_cast<LazySymbol>(this))
    return l->signature;
  return nullptr;
}

InputChunk *Symbol::getChunk() const {
  if (auto *f = dyn_cast<DefinedFunction>(this))
    return f->function;
  if (auto *d = dyn_cast<DefinedData>(this))
    return d->segment;
  return nullptr;
}

bool Symbol::isDiscarded() const {
  if (InputChunk *c = getChunk())
    return c->discarded;
  return false;
}

bool Symbol::isLive() const {
  if (auto *g = dyn_cast<DefinedGlobal>(this))
    return g->global->live;
  if (auto *e = dyn_cast<DefinedEvent>(this))
    return e->event->live;
  if (InputChunk *c = getChunk())
    return c->live;
  return referenced;
}

void Symbol::markLive() {
  assert(!isDiscarded());
  if (auto *g = dyn_cast<DefinedGlobal>(this))
    g->global->live = true;
  if (auto *e = dyn_cast<DefinedEvent>(this))
    e->event->live = true;
  if (InputChunk *c = getChunk())
    c->live = true;
  referenced = true;
}

uint32_t Symbol::getOutputSymbolIndex() const {
  assert(outputSymbolIndex != INVALID_INDEX);
  return outputSymbolIndex;
}

void Symbol::setOutputSymbolIndex(uint32_t index) {
  LLVM_DEBUG(dbgs() << "setOutputSymbolIndex " << name << " -> " << index
                    << "\n");
  assert(outputSymbolIndex == INVALID_INDEX);
  outputSymbolIndex = index;
}

void Symbol::setGOTIndex(uint32_t index) {
  LLVM_DEBUG(dbgs() << "setGOTIndex " << name << " -> " << index << "\n");
  assert(gotIndex == INVALID_INDEX);
  // Any symbol that is assigned a GOT entry must be exported othewise the
  // dynamic linker won't be able create the entry that contains it.
  forceExport = true;
  gotIndex = index;
}

bool Symbol::isWeak() const {
  return (flags & WASM_SYMBOL_BINDING_MASK) == WASM_SYMBOL_BINDING_WEAK;
}

bool Symbol::isLocal() const {
  return (flags & WASM_SYMBOL_BINDING_MASK) == WASM_SYMBOL_BINDING_LOCAL;
}

bool Symbol::isHidden() const {
  return (flags & WASM_SYMBOL_VISIBILITY_MASK) == WASM_SYMBOL_VISIBILITY_HIDDEN;
}

void Symbol::setHidden(bool isHidden) {
  LLVM_DEBUG(dbgs() << "setHidden: " << name << " -> " << isHidden << "\n");
  flags &= ~WASM_SYMBOL_VISIBILITY_MASK;
  if (isHidden)
    flags |= WASM_SYMBOL_VISIBILITY_HIDDEN;
  else
    flags |= WASM_SYMBOL_VISIBILITY_DEFAULT;
}

bool Symbol::isExported() const {
  if (!isDefined() || isLocal())
    return false;

  if (forceExport || config->exportAll)
    return true;

  if (config->exportDynamic && !isHidden())
    return true;

  return flags & WASM_SYMBOL_EXPORTED;
}

uint32_t FunctionSymbol::getFunctionIndex() const {
  if (auto *f = dyn_cast<DefinedFunction>(this))
    return f->function->getFunctionIndex();
  assert(functionIndex != INVALID_INDEX);
  return functionIndex;
}

void FunctionSymbol::setFunctionIndex(uint32_t index) {
  LLVM_DEBUG(dbgs() << "setFunctionIndex " << name << " -> " << index << "\n");
  assert(functionIndex == INVALID_INDEX);
  functionIndex = index;
}

bool FunctionSymbol::hasFunctionIndex() const {
  if (auto *f = dyn_cast<DefinedFunction>(this))
    return f->function->hasFunctionIndex();
  return functionIndex != INVALID_INDEX;
}

uint32_t FunctionSymbol::getTableIndex() const {
  if (auto *f = dyn_cast<DefinedFunction>(this))
    return f->function->getTableIndex();
  assert(tableIndex != INVALID_INDEX);
  return tableIndex;
}

bool FunctionSymbol::hasTableIndex() const {
  if (auto *f = dyn_cast<DefinedFunction>(this))
    return f->function->hasTableIndex();
  return tableIndex != INVALID_INDEX;
}

void FunctionSymbol::setTableIndex(uint32_t index) {
  // For imports, we set the table index here on the Symbol; for defined
  // functions we set the index on the InputFunction so that we don't export
  // the same thing twice (keeps the table size down).
  if (auto *f = dyn_cast<DefinedFunction>(this)) {
    f->function->setTableIndex(index);
    return;
  }
  LLVM_DEBUG(dbgs() << "setTableIndex " << name << " -> " << index << "\n");
  assert(tableIndex == INVALID_INDEX);
  tableIndex = index;
}

DefinedFunction::DefinedFunction(StringRef name, uint32_t flags, InputFile *f,
                                 InputFunction *function)
    : FunctionSymbol(name, DefinedFunctionKind, flags, f,
                     function ? &function->signature : nullptr),
      function(function) {}

uint32_t DefinedData::getVirtualAddress() const {
  LLVM_DEBUG(dbgs() << "getVirtualAddress: " << getName() << "\n");
  if (segment) {
    // For thread local data, the symbol location is relative to the start of
    // the .tdata section, since they are used as offsets from __tls_base.
    // Hence, we do not add in segment->outputSeg->startVA.
    if (segment->outputSeg->name == ".tdata")
      return segment->outputSegmentOffset + offset;
    return segment->outputSeg->startVA + segment->outputSegmentOffset + offset;
  }
  return offset;
}

void DefinedData::setVirtualAddress(uint32_t value) {
  LLVM_DEBUG(dbgs() << "setVirtualAddress " << name << " -> " << value << "\n");
  assert(!segment);
  offset = value;
}

uint32_t DefinedData::getOutputSegmentOffset() const {
  LLVM_DEBUG(dbgs() << "getOutputSegmentOffset: " << getName() << "\n");
  return segment->outputSegmentOffset + offset;
}

uint32_t DefinedData::getOutputSegmentIndex() const {
  LLVM_DEBUG(dbgs() << "getOutputSegmentIndex: " << getName() << "\n");
  return segment->outputSeg->index;
}

uint32_t GlobalSymbol::getGlobalIndex() const {
  if (auto *f = dyn_cast<DefinedGlobal>(this))
    return f->global->getGlobalIndex();
  assert(globalIndex != INVALID_INDEX);
  return globalIndex;
}

void GlobalSymbol::setGlobalIndex(uint32_t index) {
  LLVM_DEBUG(dbgs() << "setGlobalIndex " << name << " -> " << index << "\n");
  assert(globalIndex == INVALID_INDEX);
  globalIndex = index;
}

bool GlobalSymbol::hasGlobalIndex() const {
  if (auto *f = dyn_cast<DefinedGlobal>(this))
    return f->global->hasGlobalIndex();
  return globalIndex != INVALID_INDEX;
}

DefinedGlobal::DefinedGlobal(StringRef name, uint32_t flags, InputFile *file,
                             InputGlobal *global)
    : GlobalSymbol(name, DefinedGlobalKind, flags, file,
                   global ? &global->getType() : nullptr),
      global(global) {}

uint32_t EventSymbol::getEventIndex() const {
  if (auto *f = dyn_cast<DefinedEvent>(this))
    return f->event->getEventIndex();
  assert(eventIndex != INVALID_INDEX);
  return eventIndex;
}

void EventSymbol::setEventIndex(uint32_t index) {
  LLVM_DEBUG(dbgs() << "setEventIndex " << name << " -> " << index << "\n");
  assert(eventIndex == INVALID_INDEX);
  eventIndex = index;
}

bool EventSymbol::hasEventIndex() const {
  if (auto *f = dyn_cast<DefinedEvent>(this))
    return f->event->hasEventIndex();
  return eventIndex != INVALID_INDEX;
}

DefinedEvent::DefinedEvent(StringRef name, uint32_t flags, InputFile *file,
                           InputEvent *event)
    : EventSymbol(name, DefinedEventKind, flags, file,
                  event ? &event->getType() : nullptr,
                  event ? &event->signature : nullptr),
      event(event) {}

const OutputSectionSymbol *SectionSymbol::getOutputSectionSymbol() const {
  assert(section->outputSec && section->outputSec->sectionSym);
  return section->outputSec->sectionSym;
}

void LazySymbol::fetch() { cast<ArchiveFile>(file)->addMember(&archiveSymbol); }

std::string lld::toString(const wasm::Symbol &sym) {
  return lld::maybeDemangleSymbol(sym.getName());
}

std::string lld::maybeDemangleSymbol(StringRef name) {
  if (config->demangle)
    if (Optional<std::string> s = demangleItanium(name))
      return *s;
  return name;
}

std::string lld::toString(wasm::Symbol::Kind kind) {
  switch (kind) {
  case wasm::Symbol::DefinedFunctionKind:
    return "DefinedFunction";
  case wasm::Symbol::DefinedDataKind:
    return "DefinedData";
  case wasm::Symbol::DefinedGlobalKind:
    return "DefinedGlobal";
  case wasm::Symbol::DefinedEventKind:
    return "DefinedEvent";
  case wasm::Symbol::UndefinedFunctionKind:
    return "UndefinedFunction";
  case wasm::Symbol::UndefinedDataKind:
    return "UndefinedData";
  case wasm::Symbol::UndefinedGlobalKind:
    return "UndefinedGlobal";
  case wasm::Symbol::LazyKind:
    return "LazyKind";
  case wasm::Symbol::SectionKind:
    return "SectionKind";
  case wasm::Symbol::OutputSectionKind:
    return "OutputSectionKind";
  }
  llvm_unreachable("invalid symbol kind");
}


void lld::wasm::printTraceSymbolUndefined(StringRef name, const InputFile* file) {
  message(toString(file) + ": reference to " + name);
}

// Print out a log message for --trace-symbol.
void lld::wasm::printTraceSymbol(Symbol *sym) {
  // Undefined symbols are traced via printTraceSymbolUndefined
  if (sym->isUndefined())
    return;

  std::string s;
  if (sym->isLazy())
    s = ": lazy definition of ";
  else
    s = ": definition of ";

  message(toString(sym->getFile()) + s + sym->getName());
}

const char *lld::wasm::defaultModule = "env";
const char *lld::wasm::functionTableName = "__indirect_function_table";
