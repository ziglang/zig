//===- Writer.cpp ---------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "Writer.h"
#include "Config.h"
#include "InputChunks.h"
#include "InputEvent.h"
#include "InputGlobal.h"
#include "OutputSections.h"
#include "OutputSegment.h"
#include "Relocations.h"
#include "SymbolTable.h"
#include "SyntheticSections.h"
#include "WriterUtils.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "lld/Common/Strings.h"
#include "lld/Common/Threads.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/SmallSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/BinaryFormat/Wasm.h"
#include "llvm/Object/WasmTraits.h"
#include "llvm/Support/FileOutputBuffer.h"
#include "llvm/Support/Format.h"
#include "llvm/Support/FormatVariadic.h"
#include "llvm/Support/LEB128.h"

#include <cstdarg>
#include <map>

#define DEBUG_TYPE "lld"

using namespace llvm;
using namespace llvm::wasm;
using namespace lld;
using namespace lld::wasm;

static constexpr int stackAlignment = 16;

namespace {

// The writer writes a SymbolTable result to a file.
class Writer {
public:
  void run();

private:
  void openFile();

  void createInitMemoryFunction();
  void createApplyRelocationsFunction();
  void createCallCtorsFunction();
  void createInitTLSFunction();

  void assignIndexes();
  void populateSymtab();
  void populateProducers();
  void populateTargetFeatures();
  void calculateInitFunctions();
  void calculateImports();
  void calculateExports();
  void calculateCustomSections();
  void calculateTypes();
  void createOutputSegments();
  void layoutMemory();
  void createHeader();

  void addSection(OutputSection *sec);

  void addSections();

  void createCustomSections();
  void createSyntheticSections();
  void finalizeSections();

  // Custom sections
  void createRelocSections();

  void writeHeader();
  void writeSections();

  uint64_t fileSize = 0;
  uint32_t tableBase = 0;

  std::vector<WasmInitEntry> initFunctions;
  llvm::StringMap<std::vector<InputSection *>> customSectionMapping;

  // Elements that are used to construct the final output
  std::string header;
  std::vector<OutputSection *> outputSections;

  std::unique_ptr<FileOutputBuffer> buffer;

  std::vector<OutputSegment *> segments;
  llvm::SmallDenseMap<StringRef, OutputSegment *> segmentMap;
};

} // anonymous namespace

void Writer::calculateCustomSections() {
  log("calculateCustomSections");
  bool stripDebug = config->stripDebug || config->stripAll;
  for (ObjFile *file : symtab->objectFiles) {
    for (InputSection *section : file->customSections) {
      StringRef name = section->getName();
      // These custom sections are known the linker and synthesized rather than
      // blindly copied
      if (name == "linking" || name == "name" || name == "producers" ||
          name == "target_features" || name.startswith("reloc."))
        continue;
      // .. or it is a debug section
      if (stripDebug && name.startswith(".debug_"))
        continue;
      customSectionMapping[name].push_back(section);
    }
  }
}

void Writer::createCustomSections() {
  log("createCustomSections");
  for (auto &pair : customSectionMapping) {
    StringRef name = pair.first();
    LLVM_DEBUG(dbgs() << "createCustomSection: " << name << "\n");

    OutputSection *sec = make<CustomSection>(name, pair.second);
    if (config->relocatable || config->emitRelocs) {
      auto *sym = make<OutputSectionSymbol>(sec);
      out.linkingSec->addToSymtab(sym);
      sec->sectionSym = sym;
    }
    addSection(sec);
  }
}

// Create relocations sections in the final output.
// These are only created when relocatable output is requested.
void Writer::createRelocSections() {
  log("createRelocSections");
  // Don't use iterator here since we are adding to OutputSection
  size_t origSize = outputSections.size();
  for (size_t i = 0; i < origSize; i++) {
    LLVM_DEBUG(dbgs() << "check section " << i << "\n");
    OutputSection *sec = outputSections[i];

    // Count the number of needed sections.
    uint32_t count = sec->getNumRelocations();
    if (!count)
      continue;

    StringRef name;
    if (sec->type == WASM_SEC_DATA)
      name = "reloc.DATA";
    else if (sec->type == WASM_SEC_CODE)
      name = "reloc.CODE";
    else if (sec->type == WASM_SEC_CUSTOM)
      name = saver.save("reloc." + sec->name);
    else
      llvm_unreachable(
          "relocations only supported for code, data, or custom sections");

    addSection(make<RelocSection>(name, sec));
  }
}

void Writer::populateProducers() {
  for (ObjFile *file : symtab->objectFiles) {
    const WasmProducerInfo &info = file->getWasmObj()->getProducerInfo();
    out.producersSec->addInfo(info);
  }
}

void Writer::writeHeader() {
  memcpy(buffer->getBufferStart(), header.data(), header.size());
}

void Writer::writeSections() {
  uint8_t *buf = buffer->getBufferStart();
  parallelForEach(outputSections, [buf](OutputSection *s) {
    assert(s->isNeeded());
    s->writeTo(buf);
  });
}

// Fix the memory layout of the output binary.  This assigns memory offsets
// to each of the input data sections as well as the explicit stack region.
// The default memory layout is as follows, from low to high.
//
//  - initialized data (starting at Config->globalBase)
//  - BSS data (not currently implemented in llvm)
//  - explicit stack (Config->ZStackSize)
//  - heap start / unallocated
//
// The --stack-first option means that stack is placed before any static data.
// This can be useful since it means that stack overflow traps immediately
// rather than overwriting global data, but also increases code size since all
// static data loads and stores requires larger offsets.
void Writer::layoutMemory() {
  uint32_t memoryPtr = 0;

  auto placeStack = [&]() {
    if (config->relocatable || config->isPic)
      return;
    memoryPtr = alignTo(memoryPtr, stackAlignment);
    if (config->zStackSize != alignTo(config->zStackSize, stackAlignment))
      error("stack size must be " + Twine(stackAlignment) + "-byte aligned");
    log("mem: stack size  = " + Twine(config->zStackSize));
    log("mem: stack base  = " + Twine(memoryPtr));
    memoryPtr += config->zStackSize;
    auto *sp = cast<DefinedGlobal>(WasmSym::stackPointer);
    sp->global->global.InitExpr.Value.Int32 = memoryPtr;
    log("mem: stack top   = " + Twine(memoryPtr));
  };

  if (config->stackFirst) {
    placeStack();
  } else {
    memoryPtr = config->globalBase;
    log("mem: global base = " + Twine(config->globalBase));
  }

  if (WasmSym::globalBase)
    WasmSym::globalBase->setVirtualAddress(config->globalBase);

  uint32_t dataStart = memoryPtr;

  // Arbitrarily set __dso_handle handle to point to the start of the data
  // segments.
  if (WasmSym::dsoHandle)
    WasmSym::dsoHandle->setVirtualAddress(dataStart);

  out.dylinkSec->memAlign = 0;
  for (OutputSegment *seg : segments) {
    out.dylinkSec->memAlign = std::max(out.dylinkSec->memAlign, seg->alignment);
    memoryPtr = alignTo(memoryPtr, 1ULL << seg->alignment);
    seg->startVA = memoryPtr;
    log(formatv("mem: {0,-15} offset={1,-8} size={2,-8} align={3}", seg->name,
                memoryPtr, seg->size, seg->alignment));
    memoryPtr += seg->size;

    if (WasmSym::tlsSize && seg->name == ".tdata") {
      auto *tlsSize = cast<DefinedGlobal>(WasmSym::tlsSize);
      tlsSize->global->global.InitExpr.Value.Int32 = seg->size;
    }
  }

  // TODO: Add .bss space here.
  if (WasmSym::dataEnd)
    WasmSym::dataEnd->setVirtualAddress(memoryPtr);

  log("mem: static data = " + Twine(memoryPtr - dataStart));

  if (config->shared) {
    out.dylinkSec->memSize = memoryPtr;
    return;
  }

  if (!config->stackFirst)
    placeStack();

  // Set `__heap_base` to directly follow the end of the stack or global data.
  // The fact that this comes last means that a malloc/brk implementation
  // can grow the heap at runtime.
  log("mem: heap base   = " + Twine(memoryPtr));
  if (WasmSym::heapBase)
    WasmSym::heapBase->setVirtualAddress(memoryPtr);

  if (config->initialMemory != 0) {
    if (config->initialMemory != alignTo(config->initialMemory, WasmPageSize))
      error("initial memory must be " + Twine(WasmPageSize) + "-byte aligned");
    if (memoryPtr > config->initialMemory)
      error("initial memory too small, " + Twine(memoryPtr) + " bytes needed");
    else
      memoryPtr = config->initialMemory;
  }
  out.dylinkSec->memSize = memoryPtr;
  out.memorySec->numMemoryPages =
      alignTo(memoryPtr, WasmPageSize) / WasmPageSize;
  log("mem: total pages = " + Twine(out.memorySec->numMemoryPages));

  // Check max if explicitly supplied or required by shared memory
  if (config->maxMemory != 0 || config->sharedMemory) {
    if (config->maxMemory != alignTo(config->maxMemory, WasmPageSize))
      error("maximum memory must be " + Twine(WasmPageSize) + "-byte aligned");
    if (memoryPtr > config->maxMemory)
      error("maximum memory too small, " + Twine(memoryPtr) + " bytes needed");
    out.memorySec->maxMemoryPages = config->maxMemory / WasmPageSize;
    log("mem: max pages   = " + Twine(out.memorySec->maxMemoryPages));
  }
}

void Writer::addSection(OutputSection *sec) {
  if (!sec->isNeeded())
    return;
  log("addSection: " + toString(*sec));
  sec->sectionIndex = outputSections.size();
  outputSections.push_back(sec);
}

// If a section name is valid as a C identifier (which is rare because of
// the leading '.'), linkers are expected to define __start_<secname> and
// __stop_<secname> symbols. They are at beginning and end of the section,
// respectively. This is not requested by the ELF standard, but GNU ld and
// gold provide the feature, and used by many programs.
static void addStartStopSymbols(const OutputSegment *seg) {
  StringRef name = seg->name;
  if (!isValidCIdentifier(name))
    return;
  LLVM_DEBUG(dbgs() << "addStartStopSymbols: " << name << "\n");
  uint32_t start = seg->startVA;
  uint32_t stop = start + seg->size;
  symtab->addOptionalDataSymbol(saver.save("__start_" + name), start);
  symtab->addOptionalDataSymbol(saver.save("__stop_" + name), stop);
}

void Writer::addSections() {
  addSection(out.dylinkSec);
  addSection(out.typeSec);
  addSection(out.importSec);
  addSection(out.functionSec);
  addSection(out.tableSec);
  addSection(out.memorySec);
  addSection(out.globalSec);
  addSection(out.eventSec);
  addSection(out.exportSec);
  addSection(out.elemSec);
  addSection(out.dataCountSec);

  addSection(make<CodeSection>(out.functionSec->inputFunctions));
  addSection(make<DataSection>(segments));

  createCustomSections();

  addSection(out.linkingSec);
  if (config->emitRelocs || config->relocatable) {
    createRelocSections();
  }

  addSection(out.nameSec);
  addSection(out.producersSec);
  addSection(out.targetFeaturesSec);
}

void Writer::finalizeSections() {
  for (OutputSection *s : outputSections) {
    s->setOffset(fileSize);
    s->finalizeContents();
    fileSize += s->getSize();
  }
}

void Writer::populateTargetFeatures() {
  StringMap<std::string> used;
  StringMap<std::string> required;
  StringMap<std::string> disallowed;
  bool tlsUsed = false;

  // Only infer used features if user did not specify features
  bool inferFeatures = !config->features.hasValue();

  if (!inferFeatures) {
    for (auto &feature : config->features.getValue())
      out.targetFeaturesSec->features.insert(feature);
    // No need to read or check features
    if (!config->checkFeatures)
      return;
  }

  // Find the sets of used, required, and disallowed features
  for (ObjFile *file : symtab->objectFiles) {
    StringRef fileName(file->getName());
    for (auto &feature : file->getWasmObj()->getTargetFeatures()) {
      switch (feature.Prefix) {
      case WASM_FEATURE_PREFIX_USED:
        used.insert({feature.Name, fileName});
        break;
      case WASM_FEATURE_PREFIX_REQUIRED:
        used.insert({feature.Name, fileName});
        required.insert({feature.Name, fileName});
        break;
      case WASM_FEATURE_PREFIX_DISALLOWED:
        disallowed.insert({feature.Name, fileName});
        break;
      default:
        error("Unrecognized feature policy prefix " +
              std::to_string(feature.Prefix));
      }
    }

    for (InputSegment *segment : file->segments) {
      if (!segment->live)
        continue;
      StringRef name = segment->getName();
      if (name.startswith(".tdata") || name.startswith(".tbss"))
        tlsUsed = true;
    }
  }

  if (inferFeatures)
    out.targetFeaturesSec->features.insert(used.keys().begin(),
                                           used.keys().end());

  if (out.targetFeaturesSec->features.count("atomics") &&
      !config->sharedMemory) {
    if (inferFeatures)
      error(Twine("'atomics' feature is used by ") + used["atomics"] +
            ", so --shared-memory must be used");
    else
      error("'atomics' feature is used, so --shared-memory must be used");
  }

  if (!config->checkFeatures)
    return;

  if (disallowed.count("atomics") && config->sharedMemory)
    error("'atomics' feature is disallowed by " + disallowed["atomics"] +
          ", so --shared-memory must not be used");

  if (!used.count("bulk-memory") && config->passiveSegments)
    error("'bulk-memory' feature must be used in order to emit passive "
          "segments");

  if (!used.count("bulk-memory") && tlsUsed)
    error("'bulk-memory' feature must be used in order to use thread-local "
          "storage");

  // Validate that used features are allowed in output
  if (!inferFeatures) {
    for (auto &feature : used.keys()) {
      if (!out.targetFeaturesSec->features.count(feature))
        error(Twine("Target feature '") + feature + "' used by " +
              used[feature] + " is not allowed.");
    }
  }

  // Validate the required and disallowed constraints for each file
  for (ObjFile *file : symtab->objectFiles) {
    StringRef fileName(file->getName());
    SmallSet<std::string, 8> objectFeatures;
    for (auto &feature : file->getWasmObj()->getTargetFeatures()) {
      if (feature.Prefix == WASM_FEATURE_PREFIX_DISALLOWED)
        continue;
      objectFeatures.insert(feature.Name);
      if (disallowed.count(feature.Name))
        error(Twine("Target feature '") + feature.Name + "' used in " +
              fileName + " is disallowed by " + disallowed[feature.Name] +
              ". Use --no-check-features to suppress.");
    }
    for (auto &feature : required.keys()) {
      if (!objectFeatures.count(feature))
        error(Twine("Missing target feature '") + feature + "' in " + fileName +
              ", required by " + required[feature] +
              ". Use --no-check-features to suppress.");
    }
  }
}

void Writer::calculateImports() {
  for (Symbol *sym : symtab->getSymbols()) {
    if (!sym->isUndefined())
      continue;
    if (sym->isWeak() && !config->relocatable)
      continue;
    if (!sym->isLive())
      continue;
    if (!sym->isUsedInRegularObj)
      continue;
    // We don't generate imports for data symbols. They however can be imported
    // as GOT entries.
    if (isa<DataSymbol>(sym))
      continue;

    LLVM_DEBUG(dbgs() << "import: " << sym->getName() << "\n");
    out.importSec->addImport(sym);
  }
}

void Writer::calculateExports() {
  if (config->relocatable)
    return;

  if (!config->relocatable && !config->importMemory)
    out.exportSec->exports.push_back(
        WasmExport{"memory", WASM_EXTERNAL_MEMORY, 0});

  if (!config->relocatable && config->exportTable)
    out.exportSec->exports.push_back(
        WasmExport{functionTableName, WASM_EXTERNAL_TABLE, 0});

  unsigned fakeGlobalIndex = out.importSec->getNumImportedGlobals() +
                             out.globalSec->inputGlobals.size();

  for (Symbol *sym : symtab->getSymbols()) {
    if (!sym->isExported())
      continue;
    if (!sym->isLive())
      continue;

    StringRef name = sym->getName();
    WasmExport export_;
    if (auto *f = dyn_cast<DefinedFunction>(sym)) {
      export_ = {name, WASM_EXTERNAL_FUNCTION, f->getFunctionIndex()};
    } else if (auto *g = dyn_cast<DefinedGlobal>(sym)) {
      // TODO(sbc): Remove this check once to mutable global proposal is
      // implement in all major browsers.
      // See: https://github.com/WebAssembly/mutable-global
      if (g->getGlobalType()->Mutable) {
        // Only __stack_pointer and __tls_base should ever be create as mutable.
        assert(g == WasmSym::stackPointer || g == WasmSym::tlsBase);
        continue;
      }
      export_ = {name, WASM_EXTERNAL_GLOBAL, g->getGlobalIndex()};
    } else if (auto *e = dyn_cast<DefinedEvent>(sym)) {
      export_ = {name, WASM_EXTERNAL_EVENT, e->getEventIndex()};
    } else {
      auto *d = cast<DefinedData>(sym);
      out.globalSec->definedFakeGlobals.emplace_back(d);
      export_ = {name, WASM_EXTERNAL_GLOBAL, fakeGlobalIndex++};
    }

    LLVM_DEBUG(dbgs() << "Export: " << name << "\n");
    out.exportSec->exports.push_back(export_);
  }
}

void Writer::populateSymtab() {
  if (!config->relocatable && !config->emitRelocs)
    return;

  for (Symbol *sym : symtab->getSymbols())
    if (sym->isUsedInRegularObj && sym->isLive())
      out.linkingSec->addToSymtab(sym);

  for (ObjFile *file : symtab->objectFiles) {
    LLVM_DEBUG(dbgs() << "Local symtab entries: " << file->getName() << "\n");
    for (Symbol *sym : file->getSymbols())
      if (sym->isLocal() && !isa<SectionSymbol>(sym) && sym->isLive())
        out.linkingSec->addToSymtab(sym);
  }
}

void Writer::calculateTypes() {
  // The output type section is the union of the following sets:
  // 1. Any signature used in the TYPE relocation
  // 2. The signatures of all imported functions
  // 3. The signatures of all defined functions
  // 4. The signatures of all imported events
  // 5. The signatures of all defined events

  for (ObjFile *file : symtab->objectFiles) {
    ArrayRef<WasmSignature> types = file->getWasmObj()->types();
    for (uint32_t i = 0; i < types.size(); i++)
      if (file->typeIsUsed[i])
        file->typeMap[i] = out.typeSec->registerType(types[i]);
  }

  for (const Symbol *sym : out.importSec->importedSymbols) {
    if (auto *f = dyn_cast<FunctionSymbol>(sym))
      out.typeSec->registerType(*f->signature);
    else if (auto *e = dyn_cast<EventSymbol>(sym))
      out.typeSec->registerType(*e->signature);
  }

  for (const InputFunction *f : out.functionSec->inputFunctions)
    out.typeSec->registerType(f->signature);

  for (const InputEvent *e : out.eventSec->inputEvents)
    out.typeSec->registerType(e->signature);
}

static void scanRelocations() {
  for (ObjFile *file : symtab->objectFiles) {
    LLVM_DEBUG(dbgs() << "scanRelocations: " << file->getName() << "\n");
    for (InputChunk *chunk : file->functions)
      scanRelocations(chunk);
    for (InputChunk *chunk : file->segments)
      scanRelocations(chunk);
    for (auto &p : file->customSections)
      scanRelocations(p);
  }
}

void Writer::assignIndexes() {
  // Seal the import section, since other index spaces such as function and
  // global are effected by the number of imports.
  out.importSec->seal();

  for (InputFunction *func : symtab->syntheticFunctions)
    out.functionSec->addFunction(func);

  for (ObjFile *file : symtab->objectFiles) {
    LLVM_DEBUG(dbgs() << "Functions: " << file->getName() << "\n");
    for (InputFunction *func : file->functions)
      out.functionSec->addFunction(func);
  }

  for (InputGlobal *global : symtab->syntheticGlobals)
    out.globalSec->addGlobal(global);

  for (ObjFile *file : symtab->objectFiles) {
    LLVM_DEBUG(dbgs() << "Globals: " << file->getName() << "\n");
    for (InputGlobal *global : file->globals)
      out.globalSec->addGlobal(global);
  }

  for (ObjFile *file : symtab->objectFiles) {
    LLVM_DEBUG(dbgs() << "Events: " << file->getName() << "\n");
    for (InputEvent *event : file->events)
      out.eventSec->addEvent(event);
  }
}

static StringRef getOutputDataSegmentName(StringRef name) {
  // With PIC code we currently only support a single data segment since
  // we only have a single __memory_base to use as our base address.
  if (config->isPic)
    return ".data";
  // We only support one thread-local segment, so we must merge the segments
  // despite --no-merge-data-segments.
  // We also need to merge .tbss into .tdata so they share the same offsets.
  if (name.startswith(".tdata") || name.startswith(".tbss"))
    return ".tdata";
  if (!config->mergeDataSegments)
    return name;
  if (name.startswith(".text."))
    return ".text";
  if (name.startswith(".data."))
    return ".data";
  if (name.startswith(".bss."))
    return ".bss";
  if (name.startswith(".rodata."))
    return ".rodata";
  return name;
}

void Writer::createOutputSegments() {
  for (ObjFile *file : symtab->objectFiles) {
    for (InputSegment *segment : file->segments) {
      if (!segment->live)
        continue;
      StringRef name = getOutputDataSegmentName(segment->getName());
      OutputSegment *&s = segmentMap[name];
      if (s == nullptr) {
        LLVM_DEBUG(dbgs() << "new segment: " << name << "\n");
        s = make<OutputSegment>(name, segments.size());
        if (config->passiveSegments || name == ".tdata")
          s->initFlags = WASM_SEGMENT_IS_PASSIVE;
        segments.push_back(s);
      }
      s->addInputSegment(segment);
      LLVM_DEBUG(dbgs() << "added data: " << name << ": " << s->size << "\n");
    }
  }
}

static void createFunction(DefinedFunction *func, StringRef bodyContent) {
  std::string functionBody;
  {
    raw_string_ostream os(functionBody);
    writeUleb128(os, bodyContent.size(), "function size");
    os << bodyContent;
  }
  ArrayRef<uint8_t> body = arrayRefFromStringRef(saver.save(functionBody));
  cast<SyntheticFunction>(func->function)->setBody(body);
}

void Writer::createInitMemoryFunction() {
  LLVM_DEBUG(dbgs() << "createInitMemoryFunction\n");
  std::string bodyContent;
  {
    raw_string_ostream os(bodyContent);
    writeUleb128(os, 0, "num locals");

    // initialize passive data segments
    for (const OutputSegment *s : segments) {
      if (s->initFlags & WASM_SEGMENT_IS_PASSIVE && s->name != ".tdata") {
        // destination address
        writeU8(os, WASM_OPCODE_I32_CONST, "i32.const");
        writeSleb128(os, s->startVA, "destination address");
        // source segment offset
        writeU8(os, WASM_OPCODE_I32_CONST, "i32.const");
        writeSleb128(os, 0, "segment offset");
        // memory region size
        writeU8(os, WASM_OPCODE_I32_CONST, "i32.const");
        writeSleb128(os, s->size, "memory region size");
        // memory.init instruction
        writeU8(os, WASM_OPCODE_MISC_PREFIX, "bulk-memory prefix");
        writeUleb128(os, WASM_OPCODE_MEMORY_INIT, "MEMORY.INIT");
        writeUleb128(os, s->index, "segment index immediate");
        writeU8(os, 0, "memory index immediate");
        // data.drop instruction
        writeU8(os, WASM_OPCODE_MISC_PREFIX, "bulk-memory prefix");
        writeUleb128(os, WASM_OPCODE_DATA_DROP, "DATA.DROP");
        writeUleb128(os, s->index, "segment index immediate");
      }
    }
    writeU8(os, WASM_OPCODE_END, "END");
  }

  createFunction(WasmSym::initMemory, bodyContent);
}

// For -shared (PIC) output, we create create a synthetic function which will
// apply any relocations to the data segments on startup.  This function is
// called __wasm_apply_relocs and is added at the beginning of __wasm_call_ctors
// before any of the constructors run.
void Writer::createApplyRelocationsFunction() {
  LLVM_DEBUG(dbgs() << "createApplyRelocationsFunction\n");
  // First write the body's contents to a string.
  std::string bodyContent;
  {
    raw_string_ostream os(bodyContent);
    writeUleb128(os, 0, "num locals");
    for (const OutputSegment *seg : segments)
      for (const InputSegment *inSeg : seg->inputSegments)
        inSeg->generateRelocationCode(os);
    writeU8(os, WASM_OPCODE_END, "END");
  }

  createFunction(WasmSym::applyRelocs, bodyContent);
}

// Create synthetic "__wasm_call_ctors" function based on ctor functions
// in input object.
void Writer::createCallCtorsFunction() {
  if (!WasmSym::callCtors->isLive())
    return;

  // First write the body's contents to a string.
  std::string bodyContent;
  {
    raw_string_ostream os(bodyContent);
    writeUleb128(os, 0, "num locals");

    if (config->passiveSegments) {
      writeU8(os, WASM_OPCODE_CALL, "CALL");
      writeUleb128(os, WasmSym::initMemory->getFunctionIndex(),
                   "function index");
    }

    if (config->isPic) {
      writeU8(os, WASM_OPCODE_CALL, "CALL");
      writeUleb128(os, WasmSym::applyRelocs->getFunctionIndex(),
                   "function index");
    }

    // Call constructors
    for (const WasmInitEntry &f : initFunctions) {
      writeU8(os, WASM_OPCODE_CALL, "CALL");
      writeUleb128(os, f.sym->getFunctionIndex(), "function index");
    }
    writeU8(os, WASM_OPCODE_END, "END");
  }

  createFunction(WasmSym::callCtors, bodyContent);
}

void Writer::createInitTLSFunction() {
  if (!WasmSym::initTLS->isLive())
    return;

  std::string bodyContent;
  {
    raw_string_ostream os(bodyContent);

    OutputSegment *tlsSeg = nullptr;
    for (auto *seg : segments) {
      if (seg->name == ".tdata") {
        tlsSeg = seg;
        break;
      }
    }

    writeUleb128(os, 0, "num locals");
    if (tlsSeg) {
      writeU8(os, WASM_OPCODE_LOCAL_GET, "local.get");
      writeUleb128(os, 0, "local index");

      writeU8(os, WASM_OPCODE_GLOBAL_SET, "global.set");
      writeUleb128(os, WasmSym::tlsBase->getGlobalIndex(), "global index");

      writeU8(os, WASM_OPCODE_LOCAL_GET, "local.get");
      writeUleb128(os, 0, "local index");

      writeU8(os, WASM_OPCODE_I32_CONST, "i32.const");
      writeSleb128(os, 0, "segment offset");

      writeU8(os, WASM_OPCODE_I32_CONST, "i32.const");
      writeSleb128(os, tlsSeg->size, "memory region size");

      writeU8(os, WASM_OPCODE_MISC_PREFIX, "bulk-memory prefix");
      writeUleb128(os, WASM_OPCODE_MEMORY_INIT, "MEMORY.INIT");
      writeUleb128(os, tlsSeg->index, "segment index immediate");
      writeU8(os, 0, "memory index immediate");
    }
    writeU8(os, WASM_OPCODE_END, "end function");
  }

  createFunction(WasmSym::initTLS, bodyContent);
}

// Populate InitFunctions vector with init functions from all input objects.
// This is then used either when creating the output linking section or to
// synthesize the "__wasm_call_ctors" function.
void Writer::calculateInitFunctions() {
  if (!config->relocatable && !WasmSym::callCtors->isLive())
    return;

  for (ObjFile *file : symtab->objectFiles) {
    const WasmLinkingData &l = file->getWasmObj()->linkingData();
    for (const WasmInitFunc &f : l.InitFunctions) {
      FunctionSymbol *sym = file->getFunctionSymbol(f.Symbol);
      // comdat exclusions can cause init functions be discarded.
      if (sym->isDiscarded())
        continue;
      assert(sym->isLive());
      if (*sym->signature != WasmSignature{{}, {}})
        error("invalid signature for init func: " + toString(*sym));
      LLVM_DEBUG(dbgs() << "initFunctions: " << toString(*sym) << "\n");
      initFunctions.emplace_back(WasmInitEntry{sym, f.Priority});
    }
  }

  // Sort in order of priority (lowest first) so that they are called
  // in the correct order.
  llvm::stable_sort(initFunctions,
                    [](const WasmInitEntry &l, const WasmInitEntry &r) {
                      return l.priority < r.priority;
                    });
}

void Writer::createSyntheticSections() {
  out.dylinkSec = make<DylinkSection>();
  out.typeSec = make<TypeSection>();
  out.importSec = make<ImportSection>();
  out.functionSec = make<FunctionSection>();
  out.tableSec = make<TableSection>();
  out.memorySec = make<MemorySection>();
  out.globalSec = make<GlobalSection>();
  out.eventSec = make<EventSection>();
  out.exportSec = make<ExportSection>();
  out.elemSec = make<ElemSection>(tableBase);
  out.dataCountSec = make<DataCountSection>(segments.size());
  out.linkingSec = make<LinkingSection>(initFunctions, segments);
  out.nameSec = make<NameSection>();
  out.producersSec = make<ProducersSection>();
  out.targetFeaturesSec = make<TargetFeaturesSection>();
}

void Writer::run() {
  if (config->relocatable || config->isPic)
    config->globalBase = 0;

  // For PIC code the table base is assigned dynamically by the loader.
  // For non-PIC, we start at 1 so that accessing table index 0 always traps.
  if (!config->isPic)
    tableBase = 1;

  log("-- createOutputSegments");
  createOutputSegments();
  log("-- createSyntheticSections");
  createSyntheticSections();
  log("-- populateProducers");
  populateProducers();
  log("-- populateTargetFeatures");
  populateTargetFeatures();
  log("-- calculateImports");
  calculateImports();
  log("-- layoutMemory");
  layoutMemory();

  if (!config->relocatable) {
    // Create linker synthesized __start_SECNAME/__stop_SECNAME symbols
    // This has to be done after memory layout is performed.
    for (const OutputSegment *seg : segments)
      addStartStopSymbols(seg);
  }

  log("-- scanRelocations");
  scanRelocations();
  log("-- assignIndexes");
  assignIndexes();
  log("-- calculateInitFunctions");
  calculateInitFunctions();

  if (!config->relocatable) {
    // Create linker synthesized functions
    if (config->passiveSegments)
      createInitMemoryFunction();
    if (config->isPic)
      createApplyRelocationsFunction();
    createCallCtorsFunction();
  }

  if (!config->relocatable && config->sharedMemory && !config->shared)
    createInitTLSFunction();

  if (errorCount())
    return;

  log("-- calculateTypes");
  calculateTypes();
  log("-- calculateExports");
  calculateExports();
  log("-- calculateCustomSections");
  calculateCustomSections();
  log("-- populateSymtab");
  populateSymtab();
  log("-- addSections");
  addSections();

  if (errorHandler().verbose) {
    log("Defined Functions: " + Twine(out.functionSec->inputFunctions.size()));
    log("Defined Globals  : " + Twine(out.globalSec->inputGlobals.size()));
    log("Defined Events   : " + Twine(out.eventSec->inputEvents.size()));
    log("Function Imports : " +
        Twine(out.importSec->getNumImportedFunctions()));
    log("Global Imports   : " + Twine(out.importSec->getNumImportedGlobals()));
    log("Event Imports    : " + Twine(out.importSec->getNumImportedEvents()));
    for (ObjFile *file : symtab->objectFiles)
      file->dumpInfo();
  }

  createHeader();
  log("-- finalizeSections");
  finalizeSections();

  log("-- openFile");
  openFile();
  if (errorCount())
    return;

  writeHeader();

  log("-- writeSections");
  writeSections();
  if (errorCount())
    return;

  if (Error e = buffer->commit())
    fatal("failed to write the output file: " + toString(std::move(e)));
}

// Open a result file.
void Writer::openFile() {
  log("writing: " + config->outputFile);

  Expected<std::unique_ptr<FileOutputBuffer>> bufferOrErr =
      FileOutputBuffer::create(config->outputFile, fileSize,
                               FileOutputBuffer::F_executable);

  if (!bufferOrErr)
    error("failed to open " + config->outputFile + ": " +
          toString(bufferOrErr.takeError()));
  else
    buffer = std::move(*bufferOrErr);
}

void Writer::createHeader() {
  raw_string_ostream os(header);
  writeBytes(os, WasmMagic, sizeof(WasmMagic), "wasm magic");
  writeU32(os, WasmVersion, "wasm version");
  os.flush();
  fileSize += header.size();
}

void lld::wasm::writeResult() { Writer().run(); }
